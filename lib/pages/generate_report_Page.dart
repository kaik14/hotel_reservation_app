import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ✅ 1. 定义品牌色 (与之前一致)
const Color kBrandColor = Color(0xFF313B53);

// A simple data model for the report
class ReportData {
  final DocumentSnapshot roomBooking;
  final List<DocumentSnapshot> serviceBookings;
  final double totalServiceCost;
  final int nights;

  ReportData({
    required this.roomBooking,
    required this.serviceBookings,
    required this.totalServiceCost,
    required this.nights,
  });

  double get accommodationCost {
    final data = roomBooking.data() as Map<String, dynamic>?;
    // Based on user's screenshot, room booking total cost is in 'totalAmount' field.
    // It appears to be in cents (e.g., 58000 for RM 580.00), so we divide by 100.
    return (data?['totalAmount'] as num? ?? 0.0).toDouble() / 100.0;
  }

  double get totalCost => accommodationCost + totalServiceCost;
}

// REWRITTEN to be a StatefulWidget for the new data fetching logic.
class GenerateReportPage extends StatefulWidget {
  const GenerateReportPage({super.key});

  @override
  State<GenerateReportPage> createState() => _GenerateReportPageState();
}

class _GenerateReportPageState extends State<GenerateReportPage> {
  bool _isLoading = true;
  List<DocumentSnapshot> _paidBookings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAllPaidRoomBookings();
  }

  /// NEW LOGIC: Manually fetch bookings for each user to avoid collectionGroup issues.
  Future<void> _fetchAllPaidRoomBookings() async {
    try {
      final List<DocumentSnapshot> allPaidBookings = [];
      // 1. Get all users
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // 2. Loop through each user to get their bookings
      for (final userDoc in usersSnapshot.docs) {
        final bookingsSnapshot = await userDoc.reference
            .collection('bookings')
            .where('status', isEqualTo: 'paid')
            // We also check for a field that only room bookings have, like 'roomNo'.
            // This avoids fetching 'service' bookings by mistake.
            .where('roomNo', isNull: false)
            .get();

        allPaidBookings.addAll(bookingsSnapshot.docs);
      }

      // ✅ 2. 新增：按日期倒序排序（最新的在最上面）
      allPaidBookings.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        
        // 优先用 checkOut，如果没有就用 checkIn 或 createdAt
        final tsA = dataA['checkOut'] ?? dataA['checkIn'] ?? dataA['createdAt'];
        final tsB = dataB['checkOut'] ?? dataB['checkIn'] ?? dataB['createdAt'];
        
        final timeA = (tsA as Timestamp?)?.toDate() ?? DateTime(0);
        final timeB = (tsB as Timestamp?)?.toDate() ?? DateTime(0);
        
        // 降序排列 (B 减 A)
        return timeB.compareTo(timeA);
      });

      // 3. Update the state with all the bookings found
      if (mounted) {
        setState(() {
          _paidBookings = allPaidBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Generate Report'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        // ✅ 3. 修改颜色：品牌深蓝灰
        backgroundColor: kBrandColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("An error occurred: $_error", textAlign: TextAlign.center),
        ),
      );
    }
    if (_paidBookings.isEmpty) {
      return const Center(child: Text('No paid room bookings found.'));
    }

    return ListView.builder(
      itemCount: _paidBookings.length,
      itemBuilder: (context, index) {
        final roomBooking = _paidBookings[index];
        final data = roomBooking.data() as Map<String, dynamic>?;

        // Reliably get userId from the document's path
        String? userId;
        final pathParts = roomBooking.reference.path.split('/');
        if (pathParts.length >= 4 &&
            pathParts[0] == 'users' &&
            pathParts[2] == 'bookings') {
          userId = pathParts[1];
        }

        // Use correct field names from user's screenshot
        final roomName = data?['roomTypeTitle'] ?? 'N/A';
        final checkOutDate =
            (data?['checkOut'] as Timestamp?)?.toDate() ?? DateTime.now();

        if (userId == null) {
          return ListTile(
              title: Text('Could not identify user for booking of: $roomName'));
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            String userName = 'Loading...';
            if (userSnapshot.hasData) {
              final userDoc = userSnapshot.data;
              if (userDoc != null && userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>?;
                userName =
                    "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}"
                        .trim();
                if (userName.isEmpty) userName = "Unknown Guest";
              } else {
                userName = "Unknown Guest";
              }
            } else if (userSnapshot.hasError) {
              userName = "Error";
            }

            return ListTile(
              title: Text('Room: $roomName - Guest: $userName'),
              subtitle: Text('Date: ${DateFormat.yMd().format(checkOutDate)}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReportDetailPage(roomBooking: roomBooking),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ReportDetailPage extends StatelessWidget {
  final DocumentSnapshot roomBooking;

  const ReportDetailPage({super.key, required this.roomBooking});

  Future<ReportData> _fetchReportData() async {
    final roomData = roomBooking.data() as Map<String, dynamic>;

    String? userId;
    final pathParts = roomBooking.reference.path.split('/');
    if (pathParts.length >= 4 &&
        pathParts[0] == 'users' &&
        pathParts[2] == 'bookings') {
      userId = pathParts[1];
    }
    if (userId == null) {
      throw Exception('Could not determine user from booking path.');
    }

    final checkIn = (roomData['checkIn'] as Timestamp).toDate();
    final checkOut = (roomData['checkOut'] as Timestamp).toDate();
    final nights =
        checkOut.difference(checkIn).inDays > 0 ? checkOut.difference(checkIn).inDays : 1;

    final servicesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bookings')
        .where('bookingType', isEqualTo: 'service')
        .where('serviceStart', isGreaterThanOrEqualTo: checkIn)
        .where('serviceStart', isLessThanOrEqualTo: checkOut)
        .get();

    final serviceBookings = servicesSnapshot.docs;

    final totalServiceCost =
        serviceBookings.fold<double>(0.0, (currentTotal, doc) {
      final data = doc.data();
      // Service bookings use 'totalPriceRM'
      return currentTotal + ((data['totalPriceRM'] ?? 0.0) as num).toDouble();
    });

    return ReportData(
      roomBooking: roomBooking,
      serviceBookings: serviceBookings,
      totalServiceCost: totalServiceCost,
      nights: nights,
    );
  }
  
  /// NEW: Generates the PDF document
  Future<Uint8List> _generatePdf(
      PdfPageFormat format, ReportData report) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    // Re-fetch user name for the PDF header
    String? userId;
    final pathParts = report.roomBooking.reference.path.split('/');
    if (pathParts.length >= 4 &&
        pathParts[0] == 'users' &&
        pathParts[2] == 'bookings') {
      userId = pathParts[1];
    }
    String userName = "Unknown Guest";
    if (userId != null) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        userName =
            "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}"
                .trim();
        if (userName.isEmpty) userName = "Unknown Guest";
      }
    }

    final roomData = report.roomBooking.data() as Map<String, dynamic>;
    final checkIn = (roomData['checkIn'] as Timestamp).toDate();
    final checkOut = (roomData['checkOut'] as Timestamp).toDate();
    final currencyFormat =
        NumberFormat.currency(locale: 'en_US', symbol: 'RM ');

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text('Billing Receipt',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Guest: $userName',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 18)),
              pw.Text(
                  'Stay Period: ${DateFormat.yMMMd().format(checkIn)} - ${DateFormat.yMMMd().format(checkOut)}'),
              pw.Divider(height: 32),

              // Accommodation
              pw.Text('Accommodation',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      '${roomData['roomTypeTitle'] ?? 'N/A'} (${report.nights} nights)'),
                  pw.Text(currencyFormat.format(report.accommodationCost),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(height: 32),

              // Services
              pw.Text('Additional Services',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              report.serviceBookings.isEmpty
                  ? pw.Text('No additional services during this stay.')
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: report.serviceBookings.map((service) {
                        final data = service.data() as Map<String, dynamic>;
                        final serviceName = data['serviceName'] ?? 'Unnamed Service';
                        final price = (data['totalPriceRM'] as num? ?? 0.0).toDouble();
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(serviceName),
                              pw.Text(currencyFormat.format(price)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              pw.Divider(height: 32),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 18)),
                  pw.Text(currencyFormat.format(report.totalCost),
                      style: const pw.TextStyle(fontSize: 18)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 22)),
                  pw.Text(currencyFormat.format(report.totalCost),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 22)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Removed the nested Scaffold. This is now the main layout structure.
    return FutureBuilder<ReportData>(
      future: _fetchReportData(),
      builder: (context, snapshot) {
        // Display a loading indicator or error message with a consistent AppBar
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return Scaffold(
            // ✅ 4. 设置背景纯白
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Billing Report'),
              // ✅ 5. 修改颜色：品牌深蓝灰
              backgroundColor: kBrandColor,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: snapshot.hasError
                  ? Text("Error loading report: ${snapshot.error}")
                  : const CircularProgressIndicator(),
            ),
          );
        }

        final report = snapshot.data!;
        final currencyFormat =
            NumberFormat.currency(locale: 'en_US', symbol: 'RM ');

        // This is the main Scaffold, shown only when data is successfully loaded.
        return Scaffold(
          // ✅ 4. 设置背景纯白
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Billing Report'),
            // ✅ 5. 修改颜色：品牌深蓝灰
            backgroundColor: kBrandColor,
            foregroundColor: Colors.white,
            actions: [
              // FIXED: Use Printing.sharePdf to bring up the share sheet
              IconButton(
                icon: const Icon(Icons.share), // Changed icon to 'share'
                onPressed: () async {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Generating PDF...')));

                  final pdfBytes = await _generatePdf(PdfPageFormat.a4, report);
                  
                  await Printing.sharePdf(
                      bytes: pdfBytes, filename: 'billing-receipt.pdf');
                },
                tooltip: 'Share Receipt', // Updated tooltip
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(report),
                const SizedBox(height: 24),
                _buildSectionTitle('Accommodation'),
                _buildCostRow(
                    'Room: ${report.roomBooking['roomTypeTitle'] ?? 'N/A'} (${report.nights} nights)',
                    report.accommodationCost,
                    currencyFormat),
                const Divider(height: 32),
                _buildSectionTitle('Additional Services'),
                if (report.serviceBookings.isEmpty)
                  const Text('No additional services during this stay.')
                else
                  ...report.serviceBookings.map((service) {
                    final data = service.data() as Map<String, dynamic>;
                    final serviceName =
                        data['serviceName'] ?? 'Unnamed Service';
                    final price =
                        (data['totalPriceRM'] as num? ?? 0.0).toDouble();
                    return _buildCostRow(serviceName, price, currencyFormat);
                  }),
                const Divider(height: 32),
                _buildTotalSection(report, currencyFormat),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ReportData report) {
    final roomData = report.roomBooking.data() as Map<String, dynamic>;
    final checkIn = (roomData['checkIn'] as Timestamp).toDate();
    final checkOut = (roomData['checkOut'] as Timestamp).toDate();
    
    String? userId;
    final pathParts = report.roomBooking.reference.path.split('/');
    if (pathParts.length >= 4 &&
        pathParts[0] == 'users' &&
        pathParts[2] == 'bookings') {
      userId = pathParts[1];
    }
    if (userId == null) {
      return const Text('Error: Cannot identify user for this booking.');
    }

    return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, userSnapshot) {
          String userName = 'Loading...';
          if (userSnapshot.hasData) {
            final userDoc = userSnapshot.data;
            if (userDoc != null && userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>?;
              userName =
                  "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}"
                      .trim();
              if (userName.isEmpty) userName = "Unknown Guest";
            } else {
              userName = "Unknown Guest";
            }
          } else if (userSnapshot.hasError) {
            userName = "Error fetching user";
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guest: $userName',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'Stay Period: ${DateFormat.yMMMd().format(checkIn)} - ${DateFormat.yMMMd().format(checkOut)}'),
            ],
          );
        });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
    );
  }

  Widget _buildCostRow(String description, num amount, NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(description, style: const TextStyle(fontSize: 16))),
          Text(format.format(amount),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalSection(ReportData report, NumberFormat format) {
    return Column(
      children: [
        _buildCostRow('Subtotal', report.totalCost, format),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(format.format(report.totalCost),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}