// Dashboard.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase/webPage/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase/core/utils/image_constant.dart';
import 'package:firebase/webPage/booking.dart';
import 'package:firebase/webPage/employee.dart';
import 'package:firebase/webPage/map_management.dart';
import 'package:firebase/webPage/setting_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart';

class Dashboard extends StatefulWidget {
  final String empId;

  const Dashboard({Key? key, required this.empId}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<FlSpot> lineChartData = [];
  Map<String, double> pieChartDataMostDisliked = {};
  Map<String, double> pieChartDataMostPopular = {};
  int totalReservations = 0;
  int changedReservations = 0;
  double avgDailyReservations = 0;
  int currentDesksEnabled = 0;
  DateTime earliestDate = DateTime.now();
  DateTime latestDate = DateTime.now();
  DateTime selectedStartDate = DateTime.now();
  DateTime selectedEndDate = DateTime.now();
  bool isLoading = true;
  bool isExporting = false;

  GlobalKey _lineChartKey = GlobalKey();
  GlobalKey _dislikedPieChartKey = GlobalKey();
  GlobalKey _popularPieChartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Please login first!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      _fetchInitialData();
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      QuerySnapshot bookingsSnapshot =
          await FirebaseFirestore.instance.collection('booking').get();

      if (bookingsSnapshot.docs.isNotEmpty) {
        DateTime firstDate = DateTime.now();
        DateTime lastDate = DateTime.now();

        for (var doc in bookingsSnapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('booking_date')) {
            DateTime date = DateTime.parse(data['booking_date']);
            if (date.isBefore(firstDate)) firstDate = date;
            if (date.isAfter(lastDate)) lastDate = date;
          }
        }

        setState(() {
          earliestDate = firstDate;
          latestDate = lastDate;
          selectedStartDate = firstDate;
          selectedEndDate = lastDate;
        });

        _fetchData(firstDate, lastDate);
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    }
  }

  Future<void> _fetchData(DateTime startDate, DateTime endDate) async {
    try {
      QuerySnapshot bookingsSnapshot =
          await FirebaseFirestore.instance.collection('booking').get();
      QuerySnapshot deskLogSnapshot =
          await FirebaseFirestore.instance.collection('desk_log').get();
      QuerySnapshot desksSnapshot =
          await FirebaseFirestore.instance.collection('desks').get();

      // Process data for line chart
      Map<String, int> dateCounts = {};
      totalReservations = bookingsSnapshot.docs.length;

      for (var doc in bookingsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('booking_date')) {
          DateTime date = DateTime.parse(data['booking_date']);
          if (date.isAfter(startDate) && date.isBefore(endDate)) {
            String formattedDate = DateFormat('yyyy-MM-dd').format(date);
            dateCounts[formattedDate] = (dateCounts[formattedDate] ?? 0) + 1;
          }
        }
      }

      // Generate line chart data
      List<FlSpot> processedData = [];
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
        double yValue = dateCounts[formattedDate]?.toDouble() ?? 0;
        processedData.add(FlSpot(
            currentDate.difference(startDate).inDays.toDouble(), yValue));
        currentDate = currentDate.add(Duration(days: 1));
      }

      setState(() {
        lineChartData = processedData;
        avgDailyReservations = totalReservations /
            (latestDate.difference(earliestDate).inDays + 1);
        isLoading = false;
      });

      // Process data for pie charts
      changedReservations = deskLogSnapshot.docs.length;
      Map<String, int> changeCountsTo = {};
      Map<String, int> changeCountsFrom = {};
      for (var doc in deskLogSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('new_desk_id') &&
            data.containsKey('previous_desk_id')) {
          String newDeskId = data['new_desk_id'];
          String previousDeskId = data['previous_desk_id'];
          changeCountsTo[newDeskId] = (changeCountsTo[newDeskId] ?? 0) + 1;
          changeCountsFrom[previousDeskId] =
              (changeCountsFrom[previousDeskId] ?? 0) + 1;
        }
      }
      setState(() {
        pieChartDataMostPopular =
            changeCountsTo.map((key, value) => MapEntry(key, value.toDouble()));
        pieChartDataMostDisliked = changeCountsFrom
            .map((key, value) => MapEntry(key, value.toDouble()));
      });

      // Process data for current desks enabled
      currentDesksEnabled = desksSnapshot.docs.length;
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: earliestDate,
      lastDate: latestDate,
      initialDateRange: DateTimeRange(
        start: selectedStartDate,
        end: selectedEndDate,
      ),
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked.start;
        selectedEndDate = picked.end;
        isLoading = true;
        _fetchData(selectedStartDate, selectedEndDate);
      });
    }
  }

  Future<void> _exportToPDF() async {
    setState(() {
      isExporting = true;
    });

    final pdf = pw.Document();
    final dateRange =
        '${DateFormat('dd/MM/yy').format(selectedStartDate)} - ${DateFormat('dd/MM/yy').format(selectedEndDate)}';

    try {
      // Assuming _capturePng is a function that captures the widget as PNG
      final lineChartImage = await _capturePng(_lineChartKey);
      final dislikedPieChartImage = await _capturePng(_dislikedPieChartKey);
      final popularPieChartImage = await _capturePng(_popularPieChartKey);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Analysis Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Date Range: $dateRange'),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatisticContainer(
                        'Total Reservations', '$totalReservations'),
                    _buildStatisticContainer(
                        'Changed Reservations', '$changedReservations'),
                    _buildStatisticContainer('Avg. Daily Reservations',
                        avgDailyReservations.toStringAsFixed(1)),
                    _buildStatisticContainer(
                        'Current Desks Enabled', '$currentDesksEnabled'),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Desk Utilization',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                if (lineChartImage != null)
                  pw.Image(pw.MemoryImage(lineChartImage)),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Desk Change Statistics',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Most Disliked Desks:'),
                if (dislikedPieChartImage != null)
                  pw.Image(pw.MemoryImage(dislikedPieChartImage)),
                pw.SizedBox(height: 20),
                pw.Text('Most Popular Desks:'),
                if (popularPieChartImage != null)
                  pw.Image(pw.MemoryImage(popularPieChartImage)),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        downloadPdfWeb(pdfBytes);
      } else {
        // Handle other platforms if necessary
      }

      setState(() {
        isExporting = false;
      });

      _showDownloadAlert();
    } catch (e) {
      print('Error generating PDF: $e');
      setState(() {
        isExporting = false;
      });
    }
  }

  pw.Widget _buildStatisticContainer(String title, String value) {
    return pw.Container(
      width: 100,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDownloadAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Download Complete'),
          content: Text('The PDF has been successfully downloaded.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  String formatXAxisLabel(double value) {
    DateTime date = selectedStartDate.add(Duration(days: value.toInt()));
    return DateFormat('MM/dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Row(
                  children: [
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: _buildNavigationDrawerContent(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatCard('Total reservations',
                                    totalReservations.toString()),
                                _buildStatCard('Changed reservations',
                                    changedReservations.toString()),
                                _buildStatCard('Avg. daily reservations',
                                    avgDailyReservations.toStringAsFixed(1)),
                                _buildStatCard('Current desks enabled',
                                    currentDesksEnabled.toString()),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _selectDateRange(context),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Date Range: ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            hintText: DateFormat('dd/MM/yy')
                                                .format(selectedStartDate),
                                          ),
                                          onTap: () =>
                                              _selectDateRange(context),
                                        ),
                                      ),
                                      Text(' - '),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            hintText: DateFormat('dd/MM/yy')
                                                .format(selectedEndDate),
                                          ),
                                          onTap: () =>
                                              _selectDateRange(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _exportToPDF,
                                  child: Text('Generate Report'),
                                ),
                              ],
                            ),
                            SizedBox(height: 30),
                            Text(
                              'Desk utilization',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Container(
                              height: 200,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: RepaintBoundary(
                                  key: _lineChartKey,
                                  child: LineChart(LineChartData(
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: lineChartData,
                                        isCurved: true,
                                        barWidth: 4,
                                        color: Colors.blue,
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        axisNameWidget: Text('Total Bookings',
                                            style: TextStyle(fontSize: 12)),
                                        axisNameSize: 30,
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            return value % 1 == 0
                                                ? Text(value.toInt().toString())
                                                : Container();
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        axisNameWidget: Text('Date',
                                            style: TextStyle(fontSize: 12)),
                                        axisNameSize: 22,
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 22,
                                          interval: 7,
                                          getTitlesWidget: (value, meta) {
                                            String label =
                                                formatXAxisLabel(value);
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(label,
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    minX: 0,
                                    maxX: selectedEndDate
                                        .difference(selectedStartDate)
                                        .inDays
                                        .toDouble(),
                                    minY: 0,
                                    maxY: (lineChartData
                                                .map((spot) => spot.y)
                                                .reduce(
                                                    (a, b) => a > b ? a : b) *
                                            1.2)
                                        .toDouble(),
                                  )),
                                ),
                              ),
                            ),
                            Text(
                              'Desk Changes Statistics',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  height: 2),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: Center(
                                            child: Text(
                                              'Most Disliked Desks',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: RepaintBoundary(
                                            key: _dislikedPieChartKey,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: PieChart(
                                                    PieChartData(
                                                      sections: pieChartDataMostDisliked
                                                          .entries
                                                          .where((entry) =>
                                                              entry.value >
                                                              0) // Ensure value is positive
                                                          .toList()
                                                          .sublist(0,
                                                              5) // Take only top 5 entries
                                                          .map((entry) {
                                                        final int index =
                                                            pieChartDataMostDisliked
                                                                .keys
                                                                .toList()
                                                                .indexOf(
                                                                    entry.key);
                                                        final Color color = Colors
                                                                .primaries[
                                                            index %
                                                                Colors.primaries
                                                                    .length];
                                                        return PieChartSectionData(
                                                          title:
                                                              '${entry.value.toInt()}',
                                                          value: entry.value,
                                                          color: color,
                                                          titleStyle: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      sectionsSpace: 4,
                                                      centerSpaceRadius: 40,
                                                      pieTouchData:
                                                          PieTouchData(
                                                        touchCallback:
                                                            (FlTouchEvent event,
                                                                pieTouchResponse) {
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: pieChartDataMostDisliked
                                                      .entries
                                                      .where((entry) =>
                                                          entry.value >
                                                          0) // Ensure value is positive
                                                      .toList()
                                                      .sublist(0,
                                                          5) // Take only top 5 entries
                                                      .map((entry) {
                                                    final int index =
                                                        pieChartDataMostDisliked
                                                            .keys
                                                            .toList()
                                                            .indexOf(entry.key);
                                                    final Color color =
                                                        Colors.primaries[index %
                                                            Colors.primaries
                                                                .length];
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 16,
                                                            height: 16,
                                                            color: color,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(entry.key),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: Center(
                                            child: Text(
                                              'Most Popular Desks',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: RepaintBoundary(
                                            key: _popularPieChartKey,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: PieChart(
                                                    PieChartData(
                                                      sections: pieChartDataMostPopular
                                                          .entries
                                                          .where((entry) =>
                                                              entry.value >
                                                              0) // Ensure value is positive
                                                          .toList()
                                                          .sublist(0,
                                                              5) // Take only top 5 entries
                                                          .map((entry) {
                                                        final int index =
                                                            pieChartDataMostPopular
                                                                .keys
                                                                .toList()
                                                                .indexOf(
                                                                    entry.key);
                                                        final Color color = Colors
                                                                .primaries[
                                                            index %
                                                                Colors.primaries
                                                                    .length];
                                                        return PieChartSectionData(
                                                          title:
                                                              '${entry.value.toInt()}',
                                                          value: entry.value,
                                                          color: color,
                                                          titleStyle: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      sectionsSpace: 4,
                                                      centerSpaceRadius: 40,
                                                      pieTouchData:
                                                          PieTouchData(
                                                        touchCallback:
                                                            (FlTouchEvent event,
                                                                pieTouchResponse) {
                                                          setState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: pieChartDataMostPopular
                                                      .entries
                                                      .where((entry) =>
                                                          entry.value >
                                                          0) // Ensure value is positive
                                                      .toList()
                                                      .sublist(0,
                                                          5) // Take only top 5 entries
                                                      .map((entry) {
                                                    final int index =
                                                        pieChartDataMostPopular
                                                            .keys
                                                            .toList()
                                                            .indexOf(entry.key);
                                                    final Color color =
                                                        Colors.primaries[index %
                                                            Colors.primaries
                                                                .length];
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4.0),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 16,
                                                            height: 16,
                                                            color: color,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(entry.key),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isExporting)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Preparing to download...',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildNavigationDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Dashboard(
                        empId: widget.empId,
                      )),
            );
          },
          child: Container(
            height: 84,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(ImageConstant.imgImage184x428),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        ListTile(
          title: Text('Booking'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingSystem(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Employee'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeePage(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Map management'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomSeatMap(),
              ),
            );
          },
        ),
        ListTile(
          title: Text('Settings'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingScreen(empId: widget.empId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Adjusted padding
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4), // Adjusted spacing
            Text(
              value,
              style: TextStyle(fontSize: 20), // Adjusted font size
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: _buildNavigationDrawerContent(),
    );
  }
}
