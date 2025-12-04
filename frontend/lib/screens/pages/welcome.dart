import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/routes.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      "title": "Track Your Wellness",
      "subtitle":
          "Stay on top of your daily habits, mood, and lifestyle in one clean dashboard.",
      "image":
          "https://cdn-icons-png.flaticon.com/512/706/706164.png", // wellness illustration
    },
    {
      "title": "Connect & Grow",
      "subtitle":
          "Engage with a community of like-minded people to stay motivated and inspired.",
      "image":
          "https://cdn-icons-png.flaticon.com/512/3898/3898082.png", // community illustration
    },
    {
      "title": "Live Sustainably",
      "subtitle":
          "Build routines that improve your health while being kind to the planet.",
      "image":
          "https://cdn-icons-png.flaticon.com/512/2906/2906895.png", // sustainability illustration
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Attractive graphic
                        Image.network(
                          slide["image"]!,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide["title"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide["subtitle"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            // ignore: deprecated_member_use
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 10,
                  width: _currentPage == index ? 24 : 10,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF019863)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF019863),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (_currentPage == slides.length - 1) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == slides.length - 1 ? "Get Started" : "Next",
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
