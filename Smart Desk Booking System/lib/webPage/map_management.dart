import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum SeatType { individual, faceToFace }

class Seat {
  final String name;
  final String? deskIdA;
  final String? deskIdB;
  final SeatType type;

  Seat(this.name, {this.deskIdA, this.deskIdB, required this.type});
}

class Desk {
  final String id;
  final String description;
  final String device;
  final String location;
  final String status;

  Desk({
    required this.id,
    required this.description,
    required this.device,
    required this.location,
    required this.status,
  });
}

class CustomSeatMap extends StatefulWidget {
  @override
  _CustomSeatMapState createState() => _CustomSeatMapState();
}

class _CustomSeatMapState extends State<CustomSeatMap> {
  List<List<Seat?>> seatMap = [];
  List<Desk> allDesks = [];
  List<Desk> filteredDesks = [];
  String? _selectedDeskIdA;
  String? _selectedDeskIdB;
  SeatType _selectedSeatType = SeatType.individual;
  List<String> desksUnderRepair = [];
  int unmanagedDesksCount = 0;
  Seat? draggedSeat;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshData();
    _searchController.addListener(_filterDesks);
  }

  void _refreshData() async {
    await _fetchSeatsFromFirestore();
    await _fetchAllDesks();
    if (mounted) {
      _updateUnmanagedDesksCount();
    }
  }

  Future<void> _fetchSeatsFromFirestore() async {
    try {
      QuerySnapshot seatSnapshot =
          await FirebaseFirestore.instance.collection('desks').get();

      seatMap.clear();
      desksUnderRepair.clear();

      Map<String, String> deskIdMap = {};
      for (var doc in seatSnapshot.docs) {
        if (doc['desk_location'] != null && doc['desk_id'] != null) {
          String deskLocation = doc['desk_location'];
          String deskId = doc['desk_id'];
          deskIdMap[deskLocation] = deskId;
          if (doc['status'] == 'under repair') {
            desksUnderRepair.add(deskId);
          }
        }
      }

      int maxRow = 0;
      int maxColumn = 0;
      for (var deskLocation in deskIdMap.keys) {
        List<int> indices = _extractIndicesFromDeskLocation(deskLocation);
        if (indices[0] > maxRow) maxRow = indices[0];
        if (indices[1] > maxColumn) maxColumn = indices[1];
      }

      for (int i = 0; i <= maxRow; i++) {
        List<Seat?> rowSeats = [];
        for (int j = 0; j <= maxColumn; j++) {
          String currentLocationA = _getLocationFromIndices(i, j, 'A');
          String currentLocationB = _getLocationFromIndices(i, j, 'B');
          String? deskIdA = deskIdMap[currentLocationA];
          String? deskIdB = deskIdMap[currentLocationB];

          if (deskIdA != null && deskIdB != null) {
            rowSeats.add(Seat('2 seats',
                deskIdA: deskIdA, deskIdB: deskIdB, type: SeatType.faceToFace));
          } else {
            String currentLocation = _getLocationFromIndices(i, j, '');
            String? deskId = deskIdMap[currentLocation];
            if (deskId != null) {
              rowSeats.add(
                  Seat('1 seat', deskIdA: deskId, type: SeatType.individual));
            } else {
              rowSeats.add(null);
            }
          }
        }
        seatMap.add(rowSeats);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error fetching seats: $e');
    }
  }

  Future<void> _fetchAllDesks() async {
    try {
      QuerySnapshot deskSnapshot =
          await FirebaseFirestore.instance.collection('desks').get();
      List<Desk> desks = deskSnapshot.docs.map((doc) {
        return Desk(
          id: doc['desk_id'],
          description: doc['desk_description'] ?? '',
          device: doc['desk_device'] ?? '',
          location: doc['desk_location'] ?? '',
          status: doc['status'] ?? '',
        );
      }).toList();
      if (mounted) {
        setState(() {
          allDesks = desks;
          filteredDesks = desks;
        });
      }
    } catch (e) {
      print('Error fetching desks: $e');
    }
  }

  void _filterDesks() {
    String keyword = _searchController.text.toLowerCase();
    setState(() {
      filteredDesks = allDesks
          .where((desk) =>
              desk.id.toLowerCase().contains(keyword) ||
              desk.description.toLowerCase().contains(keyword) ||
              desk.device.toLowerCase().contains(keyword))
          .toList();
    });
  }

  void _onSeatDrop(Seat seat, int newRow, int newCol) {
    int oldRow = -1;
    int oldCol = -1;

    for (int i = 0; i < seatMap.length; i++) {
      for (int j = 0; j < seatMap[i].length; j++) {
        if (seatMap[i][j] == seat) {
          oldRow = i;
          oldCol = j;
          break;
        }
      }
      if (oldRow != -1) break;
    }

    setState(() {
      seatMap[oldRow][oldCol] = null;
      seatMap[newRow][newCol] = seat;
      _updateDeskLocation(seat, newRow, newCol);
    });
  }

  void _updateDeskLocation(Seat seat, int row, int col) async {
    try {
      if (seat.deskIdA != null) {
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(seat.deskIdA)
            .update({
          'desk_location': _getLocationFromIndices(row, col, 'A'),
        });
      }
      if (seat.deskIdB != null) {
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(seat.deskIdB)
            .update({
          'desk_location': _getLocationFromIndices(row, col, 'B'),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desk location updated successfully.'),
          ),
        );
      }
    } catch (e) {
      print('Error updating desk location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update desk location.'),
          ),
        );
      }
    }
  }

  void _onSeatTap(int row, int col) {
    Seat? selectedSeat = seatMap[row][col];
    if (selectedSeat != null) {
      _showSwapDialog(row, col);
    } else {
      _showAddDeskDialog(row, col);
    }
  }

  void _showSwapDialog(int row, int col) {
    _selectedDeskIdA = null;
    _selectedDeskIdB = null;
    _selectedSeatType = seatMap[row][col]?.type ?? SeatType.individual;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'Swap (${seatMap[row][col]?.deskIdA ?? ''} ${seatMap[row][col]?.deskIdB ?? ''})'),
              IconButton(
                icon: Icon(Icons.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('desks')
                      .where('desk_location', isNull: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    switch (snapshot.connectionState) {
                      case ConnectionState.waiting:
                        return CircularProgressIndicator();
                      default:
                        List<String> availableDeskIds = [];
                        for (var doc in snapshot.data!.docs) {
                          availableDeskIds.add(doc['desk_id']);
                        }
                        availableDeskIds.sort(_deskIdComparator);

                        if (availableDeskIds.isEmpty) {
                          return Text('No desk available now');
                        }

                        return StatefulBuilder(
                          builder:
                              (BuildContext context, StateSetter setState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedSeatType == SeatType.faceToFace)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text('Desk ID:'),
                                  ),
                                DropdownButton<String>(
                                  value: _selectedDeskIdA,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedDeskIdA = newValue;
                                      if (_selectedDeskIdA ==
                                          _selectedDeskIdB) {
                                        _selectedDeskIdB = null;
                                      }
                                    });
                                  },
                                  items: availableDeskIds
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                                if (_selectedSeatType ==
                                    SeatType.faceToFace) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 16.0, bottom: 8.0),
                                    child: Text('Left:'),
                                  ),
                                  DropdownButton<String>(
                                    value: _selectedDeskIdB,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        if (newValue != _selectedDeskIdA) {
                                          _selectedDeskIdB = newValue;
                                        }
                                      });
                                    },
                                    items: availableDeskIds
                                        .where((deskId) =>
                                            deskId != _selectedDeskIdA)
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16.0, bottom: 8.0),
                                  child: Text('Right:'),
                                ),
                                DropdownButton<SeatType>(
                                  value: _selectedSeatType,
                                  onChanged: (SeatType? newValue) {
                                    setState(() {
                                      _selectedSeatType = newValue!;
                                      if (_selectedSeatType ==
                                          SeatType.individual) {
                                        _selectedDeskIdB = null;
                                      }
                                    });
                                  },
                                  items: SeatType.values
                                      .map<DropdownMenuItem<SeatType>>(
                                          (SeatType value) {
                                    return DropdownMenuItem<SeatType>(
                                      value: value,
                                      child: Text(value == SeatType.individual
                                          ? 'Individual'
                                          : 'Face to Face'),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _dropSeat(row, col);
                Navigator.of(context).pop();
              },
              child: Text('Drop'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedSeatType == SeatType.faceToFace &&
                    (_selectedDeskIdA == null || _selectedDeskIdB == null)) {
                  _showAlert(
                      'Please make sure you select two IDs for this type of desk.');
                } else if (_selectedDeskIdA != null &&
                    (_selectedSeatType == SeatType.individual ||
                        _selectedDeskIdB != null)) {
                  _updateDeskId(row, col, _selectedDeskIdA!, _selectedDeskIdB,
                      _selectedSeatType);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Swap'),
            ),
          ],
        );
      },
    );
  }

  void _showAddDeskDialog(int row, int col) {
    _selectedDeskIdA = null;
    _selectedDeskIdB = null;
    _selectedSeatType = SeatType.individual;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Desk'),
              IconButton(
                icon: Icon(Icons.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('desks')
                      .where('desk_location', isNull: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    switch (snapshot.connectionState) {
                      case ConnectionState.waiting:
                        return CircularProgressIndicator();
                      default:
                        List<String> availableDeskIds = [];
                        for (var doc in snapshot.data!.docs) {
                          availableDeskIds.add(doc['desk_id']);
                        }
                        availableDeskIds.sort(_deskIdComparator);

                        if (availableDeskIds.isEmpty) {
                          return Text('No desk available now');
                        }

                        return StatefulBuilder(
                          builder:
                              (BuildContext context, StateSetter setState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text('Desk ID:'),
                                ),
                                DropdownButton<String>(
                                  value: _selectedDeskIdA,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedDeskIdA = newValue;
                                      if (_selectedDeskIdA ==
                                          _selectedDeskIdB) {
                                        _selectedDeskIdB = null;
                                      }
                                    });
                                  },
                                  items: availableDeskIds
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                                if (_selectedSeatType ==
                                    SeatType.faceToFace) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 16.0, bottom: 8.0),
                                    child: Text('Left:'),
                                  ),
                                  DropdownButton<String>(
                                    value: _selectedDeskIdB,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        if (newValue != _selectedDeskIdA) {
                                          _selectedDeskIdB = newValue;
                                        }
                                      });
                                    },
                                    items: availableDeskIds
                                        .where((deskId) =>
                                            deskId != _selectedDeskIdA)
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16.0, bottom: 8.0),
                                  child: Text('Seat Type:'),
                                ),
                                DropdownButton<SeatType>(
                                  value: _selectedSeatType,
                                  onChanged: (SeatType? newValue) {
                                    setState(() {
                                      _selectedSeatType = newValue!;
                                      if (_selectedSeatType ==
                                          SeatType.individual) {
                                        _selectedDeskIdB = null;
                                      }
                                    });
                                  },
                                  items: SeatType.values
                                      .map<DropdownMenuItem<SeatType>>(
                                          (SeatType value) {
                                    return DropdownMenuItem<SeatType>(
                                      value: value,
                                      child: Text(value == SeatType.individual
                                          ? 'Individual'
                                          : 'Face to Face'),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedSeatType == SeatType.faceToFace &&
                    (_selectedDeskIdA == null || _selectedDeskIdB == null)) {
                  _showAlert(
                      'Please make sure you select two IDs for this type of desk.');
                } else if (_selectedDeskIdA != null &&
                    (_selectedSeatType == SeatType.individual ||
                        _selectedDeskIdB != null)) {
                  _addDesk(row, col, _selectedDeskIdA!, _selectedDeskIdB,
                      _selectedSeatType);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _updateDeskId(int row, int column, String newDeskIdA, String? newDeskIdB,
      SeatType seatType) async {
    String? oldDeskIdA = seatMap[row][column]?.deskIdA;
    String? oldDeskIdB = seatMap[row][column]?.deskIdB;
    if (oldDeskIdA != null) {
      try {
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(oldDeskIdA)
            .update({
          'desk_location': null,
        });
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(newDeskIdA)
            .update({
          'desk_location': seatType == SeatType.individual
              ? _getLocationFromIndices(row, column, '')
              : _getLocationFromIndices(row, column, 'A'),
        });
        if (seatType == SeatType.faceToFace && newDeskIdB != null) {
          await FirebaseFirestore.instance
              .collection('desks')
              .doc(oldDeskIdB)
              .update({
            'desk_location': null,
          });
          await FirebaseFirestore.instance
              .collection('desks')
              .doc(newDeskIdB)
              .update({
            'desk_location': _getLocationFromIndices(row, column, 'B'),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desk ID changed successfully.'),
          ),
        );
        setState(() {
          seatMap[row][column] = Seat('1 seat',
              deskIdA: newDeskIdA, deskIdB: newDeskIdB, type: seatType);
        });
      } catch (e) {
        print('Error changing desk ID: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change desk ID.'),
          ),
        );
      }
    }
  }

  String _getLocationFromIndices(int row, int column, String suffix) {
    String rowChar = String.fromCharCode('A'.codeUnitAt(0) + row);
    int colIndex = column + 1;
    return '$rowChar$colIndex$suffix';
  }

  List<int> _extractIndicesFromDeskLocation(String deskLocation) {
    String rowString = deskLocation.replaceAll(RegExp(r'[A-Z]'), '');
    String columnString = deskLocation.replaceAll(RegExp(r'[0-9]'), '');
    int column = int.parse(rowString) - 1;
    int row = columnString.codeUnitAt(0) - 'A'.codeUnitAt(0);
    return [row, column];
  }

  void _dropSeat(int row, int column) async {
    String? deskIdA = seatMap[row][column]?.deskIdA;
    String? deskIdB = seatMap[row][column]?.deskIdB;
    if (deskIdA != null) {
      try {
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(deskIdA)
            .update({
          'desk_location': null,
        });
        if (deskIdB != null) {
          await FirebaseFirestore.instance
              .collection('desks')
              .doc(deskIdB)
              .update({
            'desk_location': null,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desk location updated successfully.'),
          ),
        );
      } catch (e) {
        print('Error updating desk location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update desk location.'),
          ),
        );
      }
    }

    setState(() {
      seatMap[row][column] = null;
      _updateUnmanagedDesksCount();
    });
  }

  void _addDesk(int row, int column, String deskIdA, String? deskIdB,
      SeatType seatType) async {
    try {
      await FirebaseFirestore.instance.collection('desks').doc(deskIdA).update({
        'desk_location': seatType == SeatType.individual
            ? _getLocationFromIndices(row, column, '')
            : _getLocationFromIndices(row, column, 'A'),
      });
      if (seatType == SeatType.faceToFace && deskIdB != null) {
        await FirebaseFirestore.instance
            .collection('desks')
            .doc(deskIdB)
            .update({
          'desk_location': _getLocationFromIndices(row, column, 'B'),
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desk added successfully.'),
        ),
      );
      setState(() {
        seatMap[row][column] =
            Seat('1 seat', deskIdA: deskIdA, deskIdB: deskIdB, type: seatType);
        _updateUnmanagedDesksCount();
      });
    } catch (e) {
      print('Error adding desk: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add desk.'),
        ),
      );
    }
  }

  void _addRow() {
    setState(() {
      List<Seat?> newRow = List<Seat?>.filled(seatMap[0].length, null);
      seatMap.add(newRow);
    });
  }

  void _removeRow() {
    if (seatMap.isNotEmpty && _canRemoveRow(seatMap.length - 1)) {
      setState(() {
        seatMap.removeLast();
      });
    } else {
      _showAlert('Cannot remove row with existing desks.');
    }
  }

  bool _canRemoveRow(int row) {
    for (int col = 0; col < seatMap[row].length; col++) {
      if (seatMap[row][col] != null) return false;
    }
    return true;
  }

  void _addColumn() {
    setState(() {
      for (int i = 0; i < seatMap.length; i++) {
        seatMap[i] = List<Seat?>.from(seatMap[i])..add(null);
      }
    });
  }

  void _removeColumn() {
    if (seatMap.isNotEmpty && _canRemoveColumn(seatMap[0].length - 1)) {
      setState(() {
        for (int i = 0; i < seatMap.length; i++) {
          seatMap[i] = List<Seat?>.from(seatMap[i])..removeLast();
        }
      });
    } else {
      _showAlert('Cannot remove column with existing desks.');
    }
  }

  bool _canRemoveColumn(int column) {
    for (int row = 0; row < seatMap.length; row++) {
      if (seatMap[row][column] != null) return false;
    }
    return true;
  }

  int _deskIdComparator(String a, String b) {
    final regExp = RegExp(r'(\D+)(\d+)');
    final matchA = regExp.firstMatch(a);
    final matchB = regExp.firstMatch(b);

    if (matchA != null && matchB != null) {
      final prefixA = matchA.group(1);
      final numberA = int.tryParse(matchA.group(2) ?? '');
      final prefixB = matchB.group(1);
      final numberB = int.tryParse(matchB.group(2) ?? '');

      if (prefixA != prefixB) {
        return prefixA!.compareTo(prefixB!);
      } else {
        return numberA!.compareTo(numberB!);
      }
    }
    return a.compareTo(b);
  }

  void _updateUnmanagedDesksCount() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('desks')
          .where('desk_location', isNull: true)
          .get();
      if (mounted) {
        setState(() {
          unmanagedDesksCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching unmanaged desks: $e');
    }
  }

  void _editDesk(Desk desk) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeskScreen(desk: desk),
      ),
    ).then((_) {
      _refreshData();
    });
  }

  void _deleteDesk(Desk desk) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this desk?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _confirmDeleteDesk(desk);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteDesk(Desk desk) async {
    try {
      // Delete the desk document from Firestore
      await FirebaseFirestore.instance
          .collection('desks')
          .doc(desk.id)
          .delete();

      // Extract indices from desk location and construct new location
      List<int> deskIndices = _extractIndicesFromDeskLocation(desk.location);
      print('Desk indices: $deskIndices'); // Debugging statement

      // Remove suffix 'A' or 'B' to get the base location
      String baseLocation = desk.location.replaceAll(RegExp(r'[AB]$'), '');
      String newLocation =
          _getLocationFromIndices(deskIndices[0], deskIndices[1], '');

      print('Base location: $baseLocation'); // Debugging statement
      print('New location: $newLocation'); // Debugging statement

      for (var doc in allDesks) {
        print(
            'Checking desk: ${doc.id}, location: ${doc.location}'); // Debugging statement
        // Check if the document's location is the paired location and update it
        if (doc.location ==
            '$baseLocation${desk.location.endsWith('A') ? 'B' : 'A'}') {
          print(
              'Updating desk: ${doc.id} from ${doc.location} to $newLocation'); // Debugging statement
          await FirebaseFirestore.instance
              .collection('desks')
              .doc(doc.id)
              .update({
            'desk_location': newLocation,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desk ${desk.id} deleted successfully.'),
          ),
        );
        _refreshData(); // Ensure data is refreshed after deletion
      }
    } catch (e) {
      print('Error deleting desk: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred while deleting the desk: $e'),
          ),
        );
      }
    }
  }

  Future<void> _blockSeat(String seatId) async {
    try {
      await FirebaseFirestore.instance
          .collection('desks')
          .doc(seatId)
          .update({'status': 'under repair'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat $seatId is marked as under repair.'),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      print('Error blocking seat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred while blocking the seat.'),
          ),
        );
      }
    }
  }

  Future<void> _unblockSeat(String seatId) async {
    try {
      await FirebaseFirestore.instance
          .collection('desks')
          .doc(seatId)
          .update({'status': 'available'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat $seatId is now available.'),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      print('Error unblocking seat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred while unblocking the seat.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (seatMap.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (int i = 0; i < seatMap.length; i++)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int j = 0; j < seatMap[i].length; j++)
                                      DragTarget<Seat>(
                                        onAccept: (seat) {
                                          _onSeatDrop(seat, i, j);
                                        },
                                        builder: (context, candidateData,
                                            rejectedData) {
                                          return GestureDetector(
                                            onTap: () {
                                              _onSeatTap(i, j);
                                            },
                                            child: Draggable<Seat>(
                                              data: seatMap[i][j],
                                              feedback: Material(
                                                child: Container(
                                                  padding: EdgeInsets.all(8),
                                                  color: Colors.blue,
                                                  child: Text(
                                                      seatMap[i][j]?.deskIdA ??
                                                          ''),
                                                ),
                                              ),
                                              childWhenDragging: Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey[300],
                                                child: Icon(Icons.add,
                                                    color: Colors.black),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Container(
                                                  width: 60,
                                                  height: 60,
                                                  child: Center(
                                                    child: seatMap[i][j] != null
                                                        ? _buildSeatWidget(
                                                            seatMap[i][j])
                                                        : Container(
                                                            color: Colors
                                                                .grey[300],
                                                            child: Icon(
                                                              Icons.add,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              SizedBox(height: 16),
                              _buildLegend(),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _addRow,
                                    child: Text('Add Row'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _removeRow,
                                    child: Text('Remove Row'),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: _addColumn,
                                    child: Text('Add Column'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _removeColumn,
                                    child: Text('Remove Column'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            VerticalDivider(),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Unmanaged Desks: $unmanagedDesksCount'),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredDesks.length,
                      itemBuilder: (context, index) {
                        Desk desk = filteredDesks[index];
                        return ListTile(
                          title: Text(desk.description),
                          subtitle: Text(
                              'Device: ${desk.device}\nID: ${desk.id}\nStatus: ${desk.status}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () {
                                  _editDesk(desk);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  _deleteDesk(desk);
                                },
                              ),
                              if (desk.status != 'under repair')
                                IconButton(
                                  icon: Icon(Icons.block),
                                  onPressed: () {
                                    _blockSeat(desk.id);
                                  },
                                ),
                              if (desk.status == 'under repair')
                                IconButton(
                                  icon: Icon(Icons.check_circle),
                                  onPressed: () {
                                    _unblockSeat(desk.id);
                                  },
                                ),
                            ],
                          ),
                          onTap: () {
                            // Handle onTap event if needed
                          },
                        );
                      },
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddDeskScreen()),
                      ).then((_) {
                        _refreshData();
                      });
                    },
                    child: Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatWidget(Seat? seat) {
    if (seat == null) return Container();

    if (seat.type == SeatType.individual) {
      return Column(
        children: [
          Image.asset(
            'assets/images/img_image_24.png',
            width: 24,
            height: 24,
            color: _getDeskColor(seat.deskIdA),
          ),
          SizedBox(height: 5),
          if (seat.deskIdA != null) Text(seat.deskIdA!),
        ],
      );
    } else if (seat.type == SeatType.faceToFace) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: 3.14159 / 2,
                child: Image.asset(
                  'assets/images/img_image_24.png',
                  width: 24,
                  height: 24,
                  color: _getDeskColor(seat.deskIdA),
                ),
              ),
              SizedBox(
                width: 5,
                child: Container(
                  color: Colors.black,
                  height: 24,
                ),
              ),
              Transform.rotate(
                angle: 3 * 3.14159 / 2,
                child: Image.asset(
                  'assets/images/img_image_24.png',
                  width: 24,
                  height: 24,
                  color: _getDeskColor(seat.deskIdB),
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          if (seat.deskIdA != null && seat.deskIdB != null)
            FittedBox(
              child: Text('${seat.deskIdA!} ${seat.deskIdB!}'),
              fit: BoxFit.scaleDown,
            ),
        ],
      );
    }
    return Container();
  }

  Color _getDeskColor(String? deskId) {
    if (deskId == null) return Colors.black;
    if (desksUnderRepair.contains(deskId)) return Colors.grey;
    return Colors.black;
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.red, 'Your Booking'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.blue, 'Booked by Others'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.black, 'Available'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.grey, 'Under Repair'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          color: color,
        ),
        SizedBox(height: 4),
        Text(text),
      ],
    );
  }
}

class EditDeskScreen extends StatefulWidget {
  final Desk desk;

  const EditDeskScreen({Key? key, required this.desk}) : super(key: key);

  @override
  _EditDeskScreenState createState() => _EditDeskScreenState();
}

class _EditDeskScreenState extends State<EditDeskScreen> {
  late TextEditingController _descriptionController;
  late TextEditingController _deviceController;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.desk.description);
    _deviceController = TextEditingController(text: widget.desk.device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Desk'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Desk Description'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _deviceController,
              decoration: InputDecoration(labelText: 'Desk Device'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _saveChanges();
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveChanges() {
    String newDescription = _descriptionController.text.trim();
    String newDevice = _deviceController.text.trim();

    FirebaseFirestore.instance.collection('desks').doc(widget.desk.id).update({
      'desk_description': newDescription,
      'desk_device': newDevice,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Changes saved successfully.'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _deviceController.dispose();
    super.dispose();
  }
}

class AddDeskScreen extends StatefulWidget {
  @override
  _AddDeskScreenState createState() => _AddDeskScreenState();
}

class _AddDeskScreenState extends State<AddDeskScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _deviceController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Desk'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Desk Description'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _deviceController,
              decoration: InputDecoration(labelText: 'Desk Device'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: InputDecoration(labelText: 'Desk ID'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _addDesk();
              },
              child: Text('Add Desk'),
            ),
          ],
        ),
      ),
    );
  }

  void _addDesk() async {
    try {
      String description = _descriptionController.text.trim();
      String device = _deviceController.text.trim();
      String id = _idController.text.trim();
      String status = 'available';

      await FirebaseFirestore.instance.collection('desks').doc(id).set({
        'desk_description': description,
        'desk_device': device,
        'desk_id': id,
        'desk_location': null, // Store location as null
        'status': status,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desk added successfully.'),
        ),
      );

      _descriptionController.clear();
      _deviceController.clear();
      _idController.clear();
    } catch (e) {
      print('Error adding desk: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while adding the desk.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _deviceController.dispose();
    _idController.dispose();
    super.dispose();
  }
}

void main() {
  runApp(MaterialApp(
    home: CustomSeatMap(),
  ));
}
