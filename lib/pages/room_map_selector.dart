import 'package:flutter/material.dart';

/// ------- 房间在地图上的数据 -------

class MapRoom {
  final String roomNo;
  final double left;
  final double top;
  final double width;
  final double height;

  const MapRoom({
    required this.roomNo,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// 8 楼布局：上排 + 下排（只管 801–816 房间）

const List<MapRoom> floor08Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '0801', left: 0.12, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0803', left: 0.20, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0805', left: 0.28, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0807', left: 0.36, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0809', left: 0.44, top: 0.02, width: 0.08, height: 0.38),
  // 0.60 位置留给“电梯”
  MapRoom(roomNo: '0811', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0813', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0815', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  // 0.02 和 0.90 两边留给“楼梯”
  MapRoom(roomNo: '0802', left: 0.08, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0804', left: 0.16, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0806', left: 0.24, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0808', left: 0.32, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0810', left: 0.40, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0812', left: 0.52, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0814', left: 0.64, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0816', left: 0.76, top: 0.60, width: 0.15, height: 0.38),
];

/// 9 楼布局：和 8 楼一样，只是房号从 901–916
const List<MapRoom> floor09Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '0901', left: 0.12, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0903', left: 0.20, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0905', left: 0.28, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0907', left: 0.36, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0909', left: 0.44, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0911', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0913', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0915', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '0902', left: 0.08, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0904', left: 0.16, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0906', left: 0.24, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0908', left: 0.32, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '0910', left: 0.40, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0912', left: 0.52, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0914', left: 0.64, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '0916', left: 0.76, top: 0.60, width: 0.15, height: 0.38),
];

/// 10 楼布局
const List<MapRoom> floor10Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1001', left: 0.05, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1003', left: 0.17, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1005', left: 0.29, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1007', left: 0.41, top: 0.02, width: 0.11, height: 0.38),
  MapRoom(roomNo: '1009', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1011', left: 0.72, top: 0.02, width: 0.09, height: 0.38),
  MapRoom(roomNo: '1013', left: 0.81, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1015', left: 0.89, top: 0.02, width: 0.08, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1002', left: 0.08, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1004', left: 0.20, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1006', left: 0.32, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1008', left: 0.44, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1010', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1012', left: 0.68, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1014', left: 0.76, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1016', left: 0.84, top: 0.60, width: 0.07, height: 0.38),
];

/// 11 楼布局
const List<MapRoom> floor11Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1101', left: 0.05, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1103', left: 0.17, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1105', left: 0.29, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1107', left: 0.41, top: 0.02, width: 0.11, height: 0.38),
  MapRoom(roomNo: '1111', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1113', left: 0.72, top: 0.02, width: 0.09, height: 0.38),
  MapRoom(roomNo: '1113', left: 0.81, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1115', left: 0.89, top: 0.02, width: 0.08, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1102', left: 0.08, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1104', left: 0.20, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1106', left: 0.32, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1108', left: 0.44, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1110', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1112', left: 0.68, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1114', left: 0.76, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1116', left: 0.84, top: 0.60, width: 0.07, height: 0.38),
];

/// 12 楼布局
const List<MapRoom> floor12Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1201', left: 0.05, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1203', left: 0.17, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1205', left: 0.29, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1207', left: 0.41, top: 0.02, width: 0.11, height: 0.38),
  MapRoom(roomNo: '1209', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1211', left: 0.72, top: 0.02, width: 0.09, height: 0.38),
  MapRoom(roomNo: '1213', left: 0.81, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1215', left: 0.89, top: 0.02, width: 0.08, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1202', left: 0.08, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1204', left: 0.20, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1206', left: 0.32, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1208', left: 0.44, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1210', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1212', left: 0.68, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1214', left: 0.76, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1216', left: 0.84, top: 0.60, width: 0.07, height: 0.38),
];

/// 13 楼布局
const List<MapRoom> floor13Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1301', left: 0.05, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1303', left: 0.17, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1305', left: 0.29, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1307', left: 0.41, top: 0.02, width: 0.11, height: 0.38),
  MapRoom(roomNo: '1309', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1311', left: 0.72, top: 0.02, width: 0.09, height: 0.38),
  MapRoom(roomNo: '1313', left: 0.81, top: 0.02, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1315', left: 0.89, top: 0.02, width: 0.08, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1302', left: 0.08, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1304', left: 0.20, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1306', left: 0.32, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1308', left: 0.44, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1310', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1312', left: 0.68, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1314', left: 0.76, top: 0.60, width: 0.08, height: 0.38),
  MapRoom(roomNo: '1316', left: 0.84, top: 0.60, width: 0.07, height: 0.38),
];

/// 14 楼布局
const List<MapRoom> floor14Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1401', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1403', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1405', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1407', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1409', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1411', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1402', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1404', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1406', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1408', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1410', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1412', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 15 楼布局
const List<MapRoom> floor15Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1501', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1503', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1505', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1507', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1509', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1511', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1502', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1504', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1506', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1508', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1510', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1512', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 16 楼布局
const List<MapRoom> floor16Rooms = [
  MapRoom(roomNo: '1601', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1603', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1605', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1607', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1609', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1611', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1602', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1604', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1606', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1608', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1610', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1612', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 17 楼布局
const List<MapRoom> floor17Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1701', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1703', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1705', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1707', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1709', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1711', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1702', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1704', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1706', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1708', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1710', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1712', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 18 楼布局
const List<MapRoom> floor18Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1801', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1803', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1805', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1807', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1809', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1811', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1802', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1804', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1806', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1808', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1810', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1812', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 19 楼布局
const List<MapRoom> floor19Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '1901', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1903', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1905', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1907', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1909', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1911', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '1902', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1904', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1906', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '1908', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1910', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '1912', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 20 楼布局
const List<MapRoom> floor20Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2001', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2003', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2005', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2007', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2009', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2011', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '2002', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2004', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2006', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2008', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2010', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2012', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 21 楼布局
const List<MapRoom> floor21Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2101', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2103', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2105', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2107', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2109', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2111', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '2102', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2104', left: 0.24, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2106', left: 0.40, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2108', left: 0.56, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2110', left: 0.68, top: 0.60, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2112', left: 0.80, top: 0.60, width: 0.11, height: 0.38),
];

/// 22 楼布局
const List<MapRoom> floor22Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2201', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2207', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2209', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2211', left: 0.60, top: 0.02, width: 0.24, height: 0.38),
  MapRoom(roomNo: 'PintZone', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '2202', left: 0.08, top: 0.60, width: 0.24, height: 0.38),
  MapRoom(roomNo: '2204', left: 0.32, top: 0.60, width: 0.24, height: 0.38),
  MapRoom(roomNo: 'MeetingR1', left: 0.56, top: 0.60, width: 0.18, height: 0.38),
  MapRoom(roomNo: 'MeetingR2', left: 0.74, top: 0.60, width: 0.17, height: 0.38),
];

/// 23 楼布局
const List<MapRoom> floor23Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2301', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2307', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2309', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2311', left: 0.60, top: 0.02, width: 0.24, height: 0.38),
  MapRoom(roomNo: 'PintZone', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '2302', left: 0.08, top: 0.60, width: 0.24, height: 0.38),
  MapRoom(roomNo: '2304', left: 0.32, top: 0.60, width: 0.24, height: 0.38),
  MapRoom(roomNo: 'MeetingR3', left: 0.56, top: 0.60, width: 0.18, height: 0.38),
  MapRoom(roomNo: 'MeetingR4', left: 0.74, top: 0.60, width: 0.17, height: 0.38),
];

/// 24 楼布局
const List<MapRoom> floor24Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2401', left: 0.04, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2407', left: 0.20, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2409', left: 0.36, top: 0.02, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2411', left: 0.60, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2413', left: 0.72, top: 0.02, width: 0.12, height: 0.38),
  MapRoom(roomNo: '2415', left: 0.84, top: 0.02, width: 0.12, height: 0.38),

  // ---------- 下排 ----------
  MapRoom(roomNo: '2402', left: 0.08, top: 0.60, width: 0.16, height: 0.38),
  MapRoom(roomNo: '2404', left: 0.24, top: 0.60, width: 0.14, height: 0.38),
  MapRoom(roomNo: '2408', left: 0.38, top: 0.60, width: 0.14, height: 0.38),
  MapRoom(roomNo: '2410', left: 0.52, top: 0.60, width: 0.13, height: 0.38),
  MapRoom(roomNo: '2412', left: 0.65, top: 0.60, width: 0.13, height: 0.38),
  MapRoom(roomNo: '2416', left: 0.78, top: 0.60, width: 0.13, height: 0.38),
];
/// 25 楼布局
const List<MapRoom> floor25Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2501', left: 0.02, top: 0.02, width: 0.50, height: 0.96),
  
  // ---------- 下排 ----------
  MapRoom(roomNo: '2502', left: 0.60, top: 0.02, width: 0.37, height: 0.96),
 
];
/// 26 楼布局
const List<MapRoom> floor26Rooms = [
  // ---------- 上排 ----------
  MapRoom(roomNo: '2601', left: 0.02, top: 0.02, width: 0.50, height: 0.96),
  
  // ---------- 下排 ----------
  MapRoom(roomNo: '2602', left: 0.60, top: 0.02, width: 0.37, height: 0.96),
 
];

List<MapRoom> getRoomsForFloor(String floorId) {
  switch (floorId) {
    case '08F':
      return floor08Rooms;
    // 以后有 9F、10F 在这里继续加 case
    case '09F':
      return floor09Rooms;   // 👈 新增 9 楼
    case '10F':
      return floor10Rooms; 
    case '11F':
      return floor11Rooms;   
    case '12F':
      return floor12Rooms;   
    case '13F':
      return floor13Rooms;   
    case '14F':
      return floor14Rooms;   
    case '15F':
      return floor15Rooms;   
    case '16F':
      return floor16Rooms;   
    case '17F':
      return floor17Rooms;   
    case '18F':
      return floor18Rooms;   
    case '19F':
      return floor19Rooms;   
    case '20F':
      return floor20Rooms;   
    case '21F':
      return floor21Rooms;   
    case '22F':
      return floor22Rooms;   
    case '23F':
      return floor23Rooms; 
    case '24F':
      return floor24Rooms; 
    case '25F':
      return floor25Rooms; 
    case '26F':
      return floor26Rooms; 
    default:
      return floor08Rooms;
  }
}

/// ------- 地图选房组件 -------

class RoomMapSelector extends StatelessWidget {
  final String floorId;
  final List<String> availableRooms;
  final String? selectedRoom;
  final ValueChanged<String> onSelected;

  const RoomMapSelector({
    super.key,
    required this.floorId,
    required this.availableRooms,
    required this.selectedRoom,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final rooms = getRoomsForFloor(floorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tap a room on the map",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                children: [
                  // 背景框
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),

                  // ------- 房间块（可点击） -------
                  for (final mapRoom in rooms)
                    Positioned(
                      left: mapRoom.left * w,
                      top: mapRoom.top * h,
                      width: mapRoom.width * w,
                      height: mapRoom.height * h,
                      child: _buildRoomBox(mapRoom),
                    ),

                  // ------- 楼梯 & 电梯（不可点击，只是标注） -------

                  // 左下楼梯
                  Positioned(
                    left: 0.02 * w,
                    top: 0.60 * h,
                    width: 0.06 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Staircase", Icons.stairs),
                  ),

                  // 右下楼梯
                  Positioned(
                    left: 0.91 * w,
                    top: 0.60 * h,
                    width: 0.06 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Staircase", Icons.stairs),
                  ),

                  // 中间电梯
                  Positioned(
                    left: 0.52 * w,
                    top: 0.02 * h,
                    width: 0.08 * w,
                    height: 0.38 * h,
                    child: _buildUtilityBox("Elevator", Icons.elevator),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // 房间状态图例
        Row(
          children: [
            _buildLegendBox(Colors.blue, "Available"),
            const SizedBox(width: 12),
            _buildLegendBox(Colors.grey, "Booked"),
            const SizedBox(width: 12),
            _buildLegendBox(const Color.fromARGB(255, 239, 99, 99), "Selected", filled: true),
          ],
        ),
        const SizedBox(height: 4),


        Text(
          selectedRoom == null
              ? "Selected Room: -"
              : "Selected Room: $selectedRoom",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// ------- 单个房间块（可点击） -------

  Widget _buildRoomBox(MapRoom mapRoom) {
    final bool isAvailable = availableRooms.contains(mapRoom.roomNo);
    final bool isSelected = selectedRoom == mapRoom.roomNo;

    Color borderColor;
    Color fillColor;

    if (!isAvailable) {
      borderColor = Colors.grey;
      fillColor = Colors.grey.withOpacity(0.2);
    } else {
      borderColor = Colors.blue;
      fillColor = Colors.white;
    }

    if (isSelected) {
      borderColor = const Color.fromARGB(255, 181, 93, 93);
      fillColor = const Color.fromARGB(255, 239, 99, 99).withOpacity(0.15);
    }

    return GestureDetector(
      onTap: () {
        if (!isAvailable) return; // 已被预订不能选
        onSelected(mapRoom.roomNo);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            mapRoom.roomNo,
            style: TextStyle(
              fontSize: 12,
              color: !isAvailable ? Colors.grey.shade700 : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  /// ------- 楼梯 / 电梯标注块（不可点击） -------

  Widget _buildUtilityBox(String label, IconData icon) {
    return IgnorePointer(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.orange),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ------- 图例小方块 -------

  Widget _buildLegendBox(Color color, String label, {bool filled = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled ? color.withOpacity(0.7) : Colors.transparent,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
