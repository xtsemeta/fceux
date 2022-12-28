import 'package:badges/badges.dart';
import 'package:banner_carousel/banner_carousel.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  int badge = 0;
  final padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12);
  double gap = 10;

  var colors = [Colors.purple, Colors.pink, Colors.amber[600], Colors.teal];

  final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Emulator Home'),
        ),
        drawer: Drawer(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('This is a drawer'),
              ],
            ),
          ),
        ),
        body: PageView.builder(
          onPageChanged: (page) {
            setState(() {
              selectedIndex = page;
              badge += 1;
            });
          },
          controller: _controller,
          itemBuilder: _buildScreens,
          itemCount: 3,
        ),
        bottomNavigationBar: _buildNavBar());
  }

  Widget _buildScreens(BuildContext context, int position) {
    if (position == 0) return const HomeIndexPage();
    return Container(
      color: colors[position],
      child: Center(
        child: Text('$selectedIndex'),
      ),
    );
  }

  Widget _buildNavBar() => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              boxShadow: [
                BoxShadow(
                    spreadRadius: -10,
                    blurRadius: 60,
                    color: Colors.black.withOpacity(.4),
                    offset: const Offset(0, 25))
              ]),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
            child: GNav(
              tabs: [
                GButton(
                  gap: gap,
                  iconActiveColor: Colors.purple,
                  iconColor: Colors.black,
                  textColor: Colors.purple,
                  backgroundColor: Colors.purple.withOpacity(.2),
                  iconSize: 24,
                  padding: padding,
                  icon: LineIcons.home,
                  text: 'Home',
                ),
                GButton(
                  gap: gap,
                  iconActiveColor: Colors.pink,
                  iconColor: Colors.black,
                  textColor: Colors.pink,
                  backgroundColor: Colors.purple.withOpacity(.2),
                  iconSize: 24,
                  padding: padding,
                  icon: LineIcons.heart,
                  text: 'Category',
                  leading: selectedIndex == 1 || badge == 0
                      ? null
                      : Badge(
                          badgeColor: Colors.red.shade100,
                          elevation: 0,
                          position: BadgePosition.topEnd(top: -12, end: -12),
                          badgeContent: Text(
                            badge.toString(),
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                          child: Icon(
                            LineIcons.heart,
                            color:
                                selectedIndex == 1 ? Colors.pink : Colors.black,
                          ),
                        ),
                ),
                GButton(
                  gap: gap,
                  iconActiveColor: Colors.teal,
                  iconColor: Colors.black,
                  textColor: Colors.teal,
                  backgroundColor: Colors.purple.withOpacity(.2),
                  iconSize: 24,
                  padding: padding,
                  icon: LineIcons.user,
                  text: 'Games',
                ),
              ],
              selectedIndex: selectedIndex,
              onTabChange: (index) {
                setState(() {
                  selectedIndex = index;
                });
                _controller.jumpToPage(index);
              },
            ),
          ),
        ),
      );
}

class HomeIndexPage extends StatelessWidget {
  const HomeIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.purple[50],
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),
            BannerCarousel(
              banners: BannerImages.listBanners,
              customizedIndicators: const IndicatorModel.animation(
                  width: 15, height: 5, spaceBetween: 5, widthAnimation: 30),
              height: 200,
              activeColor: Colors.amberAccent,
              disableColor: Colors.white,
              animation: true,
              borderRadius: 10,
              indicatorBottom: false,
            ),
          ],
        ),
      ),
    );
  }
}

class BannerImages {
  static const String banner1 =
      "https://picjumbo.com/wp-content/uploads/the-golden-gate-bridge-sunset-1080x720.jpg";
  static const String banner2 =
      "https://cdn.mos.cms.futurecdn.net/Nxz3xSGwyGMaziCwiAC5WW-1024-80.jpg";
  static const String banner3 = "https://wallpaperaccess.com/full/19921.jpg";
  static const String banner4 =
      "https://images.pexels.com/photos/2635817/pexels-photo-2635817.jpeg?auto=compress&crop=focalpoint&cs=tinysrgb&fit=crop&fp-y=0.6&h=500&sharp=20&w=1400";

  static List<BannerModel> listBanners = [
    BannerModel(imagePath: banner1, id: "1"),
    BannerModel(imagePath: banner2, id: "2"),
    BannerModel(imagePath: banner3, id: "3"),
    BannerModel(imagePath: banner4, id: "4"),
  ];
}
