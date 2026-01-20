import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:marquee/marquee.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:floating/floating.dart'; // PiP Package

// --- CONFIGURATION ---
const String m3uUrl = "https://m3u.ch/pl/b3499faa747f2cd4597756dbb5ac2336_e78e8c1a1cebb153599e2d938ea41a50.m3u";
const String noticeJsonUrl = "https://raw.githubusercontent.com/v5on/api/main/notice.json";
const String telegramUrl = "https://t.me/YourChannel";
const String contactEmail = "mailto:sultan@example.com"; // আপনার ইমেইল ফরম্যাট

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MxLiveApp());
}

// --- MODELS ---
class Channel {
  final String name;
  final String logo;
  final String url;
  final String group;
  Channel({required this.name, required this.logo, required this.url, required this.group});
}

// --- APP ROOT ---
class MxLiveApp extends StatelessWidget {
  const MxLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mxliveoo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.redAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- SPLASH ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 120, height: 120, errorBuilder: (c,o,s)=>const Icon(Icons.live_tv, size: 80, color: Colors.red)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.redAccent),
          ],
        ),
      ),
    );
  }
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Channel> allChannels = [];
  List<Channel> displayedChannels = [];
  List<String> categories = ["All"];
  String selectedCategory = "All";
  String noticeMsg = "";
  bool isLoading = true;
  bool isError = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchNotice();
  }

  Future<void> fetchNotice() async {
    try {
      final res = await http.get(Uri.parse(noticeJsonUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => noticeMsg = data['notice'] ?? "");
      }
    } catch (_) {}
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse(m3uUrl));
      if (response.statusCode == 200) {
        parseM3u(response.body);
      } else {
        setState(() { isError = true; isLoading = false; });
      }
    } catch (e) {
      setState(() { isError = true; isLoading = false; });
    }
  }

  void parseM3u(String content) {
    List<String> lines = const LineSplitter().convert(content);
    List<Channel> channels = [];
    Set<String> cats = {"All"};

    String? name;
    String? logo;
    String? group;

    for (String line in lines) {
      if (line.startsWith("#EXTINF:")) {
        final nameMatch = RegExp(r',(.*)').firstMatch(line);
        name = nameMatch?.group(1)?.trim() ?? "Unknown";
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        logo = logoMatch?.group(1) ?? "";
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        group = groupMatch?.group(1) ?? "Others";
        cats.add(group);
      } else if (line.isNotEmpty && !line.startsWith("#")) {
        if (name != null) {
          channels.add(Channel(name: name, logo: logo ?? "", url: line.trim(), group: group ?? "Others"));
          name = null;
        }
      }
    }

    setState(() {
      allChannels = channels;
      displayedChannels = channels;
      categories = cats.toList()..sort();
      isLoading = false;
    });
  }

  void filterChannels(String query) {
    setState(() {
      displayedChannels = allChannels.where((channel) {
        final matchesCategory = selectedCategory == "All" || channel.group == selectedCategory;
        final matchesSearch = channel.name.toLowerCase().contains(query.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void changeCategory(String category) {
    setState(() {
      selectedCategory = category;
      searchController.clear();
      filterChannels("");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("mxliveoo"),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png', errorBuilder: (c,o,s)=>const Icon(Icons.live_tv)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage())),
          )
        ],
      ),
      body: Column(
        children: [
          if (noticeMsg.isNotEmpty)
            Container(
              height: 35,
              color: Colors.redAccent.withOpacity(0.15),
              child: Marquee(
                text: noticeMsg,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                scrollAxis: Axis.horizontal,
                blankSpace: 20.0,
                velocity: 50.0,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              onChanged: filterChannels,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search 500+ Channels...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF252525),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          if (!isLoading && !isError)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: categories.length,
                itemBuilder: (ctx, index) {
                  final cat = categories[index];
                  final isSelected = cat == selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => changeCategory(cat),
                      selectedColor: Colors.redAccent,
                      backgroundColor: const Color(0xFF252525),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 Items per row
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: displayedChannels.length,
                    itemBuilder: (ctx, index) {
                      final channel = displayedChannels[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(channel: channel, allChannels: allChannels),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252525),
                                  borderRadius: BorderRadius.circular(12),
                                  image: channel.logo.isNotEmpty
                                      ? DecorationImage(image: CachedNetworkImageProvider(channel.logo), fit: BoxFit.contain)
                                      : null,
                                ),
                                child: channel.logo.isEmpty ? const Center(child: Icon(Icons.tv, color: Colors.grey)) : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- PLAYER SCREEN (With PiP) ---
class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;
  const PlayerScreen({super.key, required this.channel, required this.allChannels});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  final Floating _floating = Floating(); // PiP Controller
  late List<Channel> relatedChannels;
  bool isPiPMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    relatedChannels = widget.allChannels
        .where((c) => c.group == widget.channel.group && c.name != widget.channel.name)
        .toList();
    initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detect when user leaves app to potentially trigger PiP automatically (if configured)
    if (state == AppLifecycleState.inactive) {
      // _enablePip(); // Optional: Auto enable on minimize
    }
  }

  Future<void> initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
    await _videoPlayerController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      isLive: true,
      aspectRatio: 16 / 9,
      allowedScreenSleep: false,
      errorBuilder: (context, errorMessage) => const Center(child: Text("Stream Error", style: TextStyle(color: Colors.red))),
    );
    setState(() {});
  }

  Future<void> _enablePip() async {
    final status = await _floating.enable(aspectRatio: const Rational.landscape());
    if (status == PiPStatus.enabled) {
      setState(() => isPiPMode = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PiPSwitcher(
      childWhenDisabled: Scaffold(
        appBar: AppBar(title: Text(widget.channel.name)),
        body: Column(
          children: [
            // VIDEO PLAYER CONTAINER
            Stack(
              alignment: Alignment.topRight,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                        ? Chewie(controller: _chewieController!)
                        : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                  ),
                ),
                // PIP BUTTON (Overlay on Video)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: _enablePip,
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                    tooltip: "Enter PiP Mode",
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                )
              ],
            ),

            // CONTENT BELOW PLAYER (Hidden in PiP)
            Expanded(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: const Color(0xFF0088CC),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.telegram, color: Colors.white),
                          SizedBox(width: 10),
                          Text("JOIN TELEGRAM CHANNEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Align(alignment: Alignment.centerLeft, child: Text("More Channels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))),
                  ),
                  
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: relatedChannels.length,
                      itemBuilder: (ctx, index) {
                        final ch = relatedChannels[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            width: 60, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(6),
                              image: ch.logo.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(ch.logo), fit: BoxFit.contain) : null,
                            ),
                          ),
                          title: Text(ch.name, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
                          onTap: () => Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: ch, allChannels: widget.allChannels))
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // PiP Mode UI (Only Video)
      childWhenEnabled: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: _chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

// --- INFO PAGE (UPDATED) ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About App")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset('assets/logo.png', width: 100, errorBuilder: (c,o,s)=>const Icon(Icons.live_tv, size: 80, color: Colors.red)),
            const SizedBox(height: 15),
            const Text("mxliveoo", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text("v1.1.0 (Premium)", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 30),
            
            // App Info Card
            _buildInfoCard(
              title: "App Features",
              content: "• 500+ Live Channels\n• Picture-in-Picture (PiP) Mode\n• Fast Streaming (M3U8/MP4)\n• Real-time Updates",
              icon: Icons.featured_play_list,
            ),
            
            const SizedBox(height: 15),

            // Dev Info Card
            _buildInfoCard(
              title: "Developer",
              content: "Name: Sultan Arabi\nRole: Lettel Developer\nFocus: Flutter & Streaming Tech",
              icon: Icons.code,
            ),

            const SizedBox(height: 30),

            // Contact Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(contactEmail)),
                icon: const Icon(Icons.email_outlined),
                label: const Text("Contact Developer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            TextButton(
              onPressed: () => launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication),
              child: const Text("Join Telegram Community", style: TextStyle(color: Color(0xFF0088CC))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String content, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Text(content, style: const TextStyle(height: 1.5, color: Colors.white70)),
        ],
      ),
    );
  }
}
