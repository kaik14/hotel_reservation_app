import 'package:flutter/material.dart';
import 'package:hotel_reservation_app/pages/room_detail_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrPC = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Find your perfect stay'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: isTabletOrPC ? 22 : 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 搜索框
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Search for your preference',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: isTabletOrPC ? 54 : 46,
                    width: isTabletOrPC ? 54 : 46,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 推荐房间
              Text(
                'Recommended Rooms',
                style: TextStyle(
                  fontSize: isTabletOrPC ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ✅ 用 SizedBox 包裹 ListView 并加上固定高度，防止 overflow
              SizedBox(
                height: isTabletOrPC ? 300 : 240,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    RoomCard(
                      title: 'Ocean View Suite',
                      price: 'RM250 per night',
                      imageUrl: 'https://picsum.photos/seed/ocean/400/250',
                    ),
                    RoomCard(
                      title: 'Mountain Retreat',
                      price: 'RM180 per night',
                      imageUrl: 'https://picsum.photos/seed/mountain/400/250',
                    ),
                    RoomCard(
                      title: 'City Apartment',
                      price: 'RM230 per night',
                      imageUrl: 'https://picsum.photos/seed/city/400/250',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 热门房间
              Text(
                'Popular Choices',
                style: TextStyle(
                  fontSize: isTabletOrPC ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ✅ 固定高度的网格布局
              SizedBox(
                height: isTabletOrPC ? 600 : 500, // ✅ 固定高度区域
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                            ? 3
                            : 2;

                    return GridView.count(
                      crossAxisCount: crossCount, // 每行多少列
                      mainAxisSpacing: 14, // 上下间距
                      crossAxisSpacing: 14, // 左右间距
                      childAspectRatio:
                          isTabletOrPC ? 1.0 : 0.8, // 卡片宽高比例
                      physics:
                          const BouncingScrollPhysics(), // ✅ 在固定高度内可轻微滑动
                      children: const [
                        PopularCard(
                          title: 'Downtown Loft',
                          price: 'RM220 per night',
                          imageUrl: 'https://picsum.photos/seed/loft/400/300',
                        ),
                        PopularCard(
                          title: 'Urban Studio',
                          price: 'RM210 per night',
                          imageUrl: 'https://picsum.photos/seed/studio/400/300',
                        ),
                        PopularCard(
                          title: 'Economy Room',
                          price: 'RM180 per night',
                          imageUrl:
                              'https://picsum.photos/seed/economy/400/300',
                        ),
                        PopularCard(
                          title: 'Standard Room',
                          price: 'RM190 per night',
                          imageUrl:
                              'https://picsum.photos/seed/standard/400/300',
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 40), // 页面底部留白
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- 推荐房卡 --------------------
class RoomCard extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;
  const RoomCard({
    required this.title,
    required this.price,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 加高度确保图片加载出来
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(price,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(90, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomDetailPage(
                        title: title,
                        imageUrl: imageUrl,
                        price: price,
                      ),
                    ),
                  );
                },
                child: const Text('Book Now', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- 热门房卡 --------------------
class PopularCard extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;
  const PopularCard({
    required this.title,
    required this.price,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(price,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(90, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomDetailPage(
                        title: title,
                        imageUrl: imageUrl,
                        price: price,
                      ),
                    ),
                  );
                },
                child: const Text('Book Now', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
