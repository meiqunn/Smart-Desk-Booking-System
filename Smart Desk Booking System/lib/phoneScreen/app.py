from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold
from sklearn.neighbors import KNeighborsClassifier
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
import numpy as np
from datetime import datetime

app = Flask(__name__)

# Initialize Firebase Admin
cred = credentials.Certificate('../../functions/serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Fetch data from Firestore
bookings = db.collection('booking').get()
desk_logs = db.collection('desk_log').get()
desks = db.collection('desks').get()

# Convert Firestore documents to DataFrame
booking_data = [b.to_dict() for b in bookings]
desk_log_data = [dl.to_dict() for dl in desk_logs]
desk_data = [d.to_dict() for d in desks]

df_booking = pd.DataFrame(booking_data)
df_desk_log = pd.DataFrame(desk_log_data)
df_desks = pd.DataFrame(desk_data)

# Preprocess data
# Encode categorical data
emp_id_category = df_booking['emp_id'].astype('category')
desk_id_category = df_booking['desk_id'].astype('category')
df_booking['emp_id'] = emp_id_category.cat.codes
df_booking['desk_id'] = desk_id_category.cat.codes
df_booking['booking_date'] = pd.to_datetime(df_booking['booking_date'])
df_booking['booking_day'] = df_booking['booking_date'].dt.day
df_booking['booking_month'] = df_booking['booking_date'].dt.month
df_booking['booking_year'] = df_booking['booking_date'].dt.year

# Incorporate desk change data
df_desk_log['changed_by'] = df_desk_log['changed_by'].astype('category').cat.codes
df_desk_log['new_desk_id'] = df_desk_log['new_desk_id'].astype('category').cat.codes
df_desk_log['previous_desk_id'] = df_desk_log['previous_desk_id'].astype('category').cat.codes

# Merge desk change data with booking data
df_booking = df_booking.merge(df_desk_log[['changed_by', 'new_desk_id', 'previous_desk_id']], 
                              left_on='emp_id', right_on='changed_by', how='left')

# Fill NaN values with -1 (indicating no change)
df_booking.fillna(-1, inplace=True)

# Drop original booking_date column if not needed
df_booking.drop(columns=['booking_date'], inplace=True)

# Add desk location data
df_desks['desk_id'] = df_desks['desk_id'].astype('category').cat.codes
df_desks['desk_location'] = df_desks['desk_location'].astype('category').cat.codes

# Merge desk location data with booking data
df_booking = df_booking.merge(df_desks[['desk_id', 'desk_location']], on='desk_id', how='left')

# Prepare features and target
X = df_booking[['emp_id', 'booking_day', 'booking_month', 'booking_year', 'desk_location', 'previous_desk_id']]
y = df_booking['desk_id']

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Define hyperparameter grids
knn_param_grid = {'n_neighbors': np.arange(1, 15)}
rf_param_grid = {'n_estimators': [100, 200, 300], 'max_depth': [None, 10, 20, 30]}
svm_param_grid = {'C': [0.1, 1, 10], 'gamma': ['scale', 'auto']}
gb_param_grid = {'n_estimators': [100, 200], 'learning_rate': [0.01, 0.1, 1.0], 'max_depth': [3, 5, 7]}
lr_param_grid = {'C': [0.1, 1, 10]}
dt_param_grid = {'max_depth': [None, 10, 20, 30], 'min_samples_split': [2, 5, 10], 'min_samples_leaf': [1, 2, 4]}

# Initialize classifiers
knn = KNeighborsClassifier()
rf = RandomForestClassifier(random_state=42)
svm = SVC(probability=True, random_state=42)  # Enable probability estimates
gb = GradientBoostingClassifier(random_state=42)
lr = LogisticRegression(random_state=42, max_iter=2000)
dt = DecisionTreeClassifier(random_state=42)

# Set up StratifiedKFold
cv = StratifiedKFold(n_splits=3)

# Perform GridSearchCV for each classifier
knn_gscv = GridSearchCV(knn, knn_param_grid, cv=cv)
rf_gscv = GridSearchCV(rf, rf_param_grid, cv=cv)
svm_gscv = GridSearchCV(svm, svm_param_grid, cv=cv)
gb_gscv = GridSearchCV(gb, gb_param_grid, cv=cv)
lr_gscv = GridSearchCV(lr, lr_param_grid, cv=cv)
dt_gscv = GridSearchCV(dt, dt_param_grid, cv=cv)

# Fit models
knn_gscv.fit(X_train, y_train)
rf_gscv.fit(X_train, y_train)
svm_gscv.fit(X_train, y_train)
gb_gscv.fit(X_train, y_train)
lr_gscv.fit(X_train, y_train)
dt_gscv.fit(X_train, y_train)

# Best parameters and accuracy
best_knn_params = knn_gscv.best_params_
best_knn_score = knn_gscv.best_score_
#print(f'KNN - Best parameters: {best_knn_params}')
#print(f'KNN - Best cross-validated accuracy: {best_knn_score}')

best_rf_params = rf_gscv.best_params_
best_rf_score = rf_gscv.best_score_
#print(f'RF - Best parameters: {best_rf_params}')
#print(f'RF - Best cross-validated accuracy: {best_rf_score}')

best_svm_params = svm_gscv.best_params_
best_svm_score = svm_gscv.best_score_
#print(f'SVM - Best parameters: {best_svm_params}')
#print(f'SVM - Best cross-validated accuracy: {best_svm_score}')

best_gb_params = gb_gscv.best_params_
best_gb_score = gb_gscv.best_score_
#print(f'GB - Best parameters: {best_gb_params}')
#print(f'GB - Best cross-validated accuracy: {best_gb_score}')

best_lr_params = lr_gscv.best_params_
best_lr_score = lr_gscv.best_score_
#print(f'LR - Best parameters: {best_lr_params}')
#print(f'LR - Best cross-validated accuracy: {best_lr_score}')

best_dt_params = dt_gscv.best_params_
best_dt_score = dt_gscv.best_score_
#print(f'DT - Best parameters: {best_dt_params}')
#print(f'DT - Best cross-validated accuracy: {best_dt_score}')

# Train the best models
knn_best = KNeighborsClassifier(**best_knn_params)
rf_best = RandomForestClassifier(**best_rf_params, random_state=42)
svm_best = SVC(**best_svm_params, probability=True, random_state=42)  # Ensure probability=True
gb_best = GradientBoostingClassifier(**best_gb_params, random_state=42)
lr_best = LogisticRegression(**best_lr_params, random_state=42, max_iter=2000)
dt_best = DecisionTreeClassifier(**best_dt_params, random_state=42)

knn_best.fit(X_train, y_train)
rf_best.fit(X_train, y_train)
svm_best.fit(X_train, y_train)
gb_best.fit(X_train, y_train)
lr_best.fit(X_train, y_train)
dt_best.fit(X_train, y_train)

# Evaluate the models
knn_accuracy = knn_best.score(X_test, y_test)
rf_accuracy = rf_best.score(X_test, y_test)
svm_accuracy = svm_best.score(X_test, y_test)
gb_accuracy = gb_best.score(X_test, y_test)
lr_accuracy = lr_best.score(X_test, y_test)
dt_accuracy = dt_best.score(X_test, y_test)
print(f'KNN Accuracy: {knn_accuracy}')
print(f'RF Accuracy: {rf_accuracy}')
print(f'SVM Accuracy: {svm_accuracy}')
print(f'GB Accuracy: {gb_accuracy}')
print(f'LR Accuracy: {lr_accuracy}')
print(f'DT Accuracy: {dt_accuracy}')

# Choose the best model based on test accuracy
best_model = max([
    (knn_best, knn_accuracy),
    (rf_best, rf_accuracy),
    (svm_best, svm_accuracy),
    (gb_best, gb_accuracy),
    (lr_best, lr_accuracy),
    (dt_best, dt_accuracy)
], key=lambda x: x[1])[0]

# Function to predict the top 5 preferred desks
def predict_top5_desks(emp_id):
    emp_code = emp_id_category.cat.categories.get_loc(emp_id)
    current_date = datetime.now()
    prediction_data = pd.DataFrame({
        'emp_id': [emp_code],
        'booking_day': [current_date.day],
        'booking_month': [current_date.month],
        'booking_year': [current_date.year],
        'desk_location': [-1],  # Example value, modify as needed
        'previous_desk_id': [-1]  # Example value, modify as needed
    })
    if hasattr(best_model, "predict_proba"):
        probs = best_model.predict_proba(prediction_data)[0]
        top5_indices = np.argsort(probs)[-5:][::-1]
    else:
        preds = best_model.predict(prediction_data)
        top5_indices = [preds[0]] * 5  # If predict_proba is not available, duplicate the prediction
    
    top5_desks = [desk_id_category.cat.categories[idx] for idx in top5_indices]
    return top5_desks

@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()
    emp_id = data['emp_id']
    print(f'Received request for emp_id: {emp_id}')  # Debug output
    top5_desks = predict_top5_desks(emp_id)
    print(f'Predicted desks: {top5_desks}')  # Debug output
    return jsonify(top5_desks)

if __name__ == '__main__':
    app.run(debug=True)
