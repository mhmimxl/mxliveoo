import 'dart:async';
import 'dart:convert';
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

// --- CONFIGURATION ---
const String m3uUrl = "https://m3u.ch/pl/b3499faa747f2cd4597756dbb5ac2336_e78e8c1a1cebb153599e2d938ea41a50.m3u";
const String noticeJsonUrl = "https://raw.githubusercontent.com/v5on/api/main/notice.json"; // আপনার জেসন লিংক এখানে দিবেন
const String telegramUrl = "https://t.me/YourChannel"; // আপনার টেলিগ্রাম লিংক

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MxLiveApp());
}

// --- DATA MODELS ---
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.redAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- SPLASH SCREEN ---
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
            Image.asset('assets/logo.png', width: 120, height: 120),
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
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

  // Fetch JSON Notice
  Future<void> fetchNotice() async {
    try {
      final res = await http.get(Uri.parse(noticeJsonUrl));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          noticeMsg = data['notice'] ?? "";
        });
      }
    } catch (_) {} // Silent fail for notice
  }

  // Fetch & Parse M3U
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
        // Parse Meta
        // Simple regex to extract data. Can be improved based on specific m3u format
        final nameMatch = RegExp(r',(.*)').firstMatch(line);
        name = nameMatch?.group(1)?.trim() ?? "Unknown Channel";

        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        logo = logoMatch?.group(1) ?? "";

        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        group = groupMatch?.group(1) ?? "Others";
        
        cats.add(group);
      } else if (line.isNotEmpty && !line.startsWith("#")) {
        // This is URL
        if (name != null) {
          channels.add(Channel(name: name, logo: logo ?? "", url: line.trim(), group: group ?? "Others"));
          name = null; // Reset
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
        title: const Text("mxliveoo", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
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
          // NOTICE BAR
          if (noticeMsg.isNotEmpty)
            Container(
              height: 30,
              color: Colors.redAccent.withOpacity(0.1),
              child: Marquee(
                text: noticeMsg,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                scrollAxis: Axis.horizontal,
                blankSpace: 20.0,
                velocity: 50.0,
              ),
            ),

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              onChanged: filterChannels,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search channels...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // CATEGORY TABS
          if (!isLoading && !isError)
            SizedBox(
              height: 40,
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
                      backgroundColor: const Color(0xFF2C2C2C),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          // GRID VIEW
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : isError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 50, color: Colors.red),
                            const SizedBox(height: 10),
                            const Text("Failed to load channels"),
                            TextButton(onPressed: fetchData, child: const Text("Retry"))
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // Requested: 4 items per row
                          childAspectRatio: 0.8,
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
                                builder: (_) => PlayerScreen(
                                  channel: channel,
                                  allChannels: allChannels, // For related list
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C2C),
                                      borderRadius: BorderRadius.circular(10),
                                      image: channel.logo.isNotEmpty
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(channel.logo),
                                              fit: BoxFit.contain,
                                            )
                                          : null,
                                    ),
                                    child: channel.logo.isEmpty
                                        ? const Center(child: Icon(Icons.tv, color: Colors.grey))
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 5),
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

// --- PLAYER SCREEN ---
class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> allChannels;

  const PlayerScreen({super.key, required this.channel, required this.allChannels});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool isError = false;
  late List<Channel> relatedChannels;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on
    // Filter related channels by same group
    relatedChannels = widget.allChannels
        .where((c) => c.group == widget.channel.group && c.name != widget.channel.name)
        .toList();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                const SizedBox(height: 10),
                Text("Stream Error: $errorMessage", style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white30,
        ),
      );
      setState(() {});
    } catch (e) {
      setState(() => isError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _launchTelegram() async {
    final uri = Uri.parse(telegramUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch Telegram")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VIDEO PLAYER AREA
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: isError
                  ? const Center(child: Text("Stream Failed to Load", style: TextStyle(color: Colors.red)))
                  : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                      ? Chewie(controller: _chewieController!)
                      : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
            ),
          ),

          // JOIN TELEGRAM BANNER
          GestureDetector(
            onTap: _launchTelegram,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF0088CC), // Telegram Blue
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.telegram, color: Colors.white),
                  SizedBox(width: 10),
                  Text("JOIN OUR TELEGRAM CHANNEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text("Related Channels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          // RELATED CHANNELS
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: relatedChannels.length,
              itemBuilder: (ctx, index) {
                final ch = relatedChannels[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(5),
                      image: ch.logo.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(ch.logo)) : null,
                    ),
                    child: ch.logo.isEmpty ? const Icon(Icons.tv, size: 20) : null,
                  ),
                  title: Text(ch.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(ch.group, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.redAccent),
                  onTap: () {
                    // Replace current player screen with new channel
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(channel: ch, allChannels: widget.allChannels),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- INFO PAGE ---
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Info")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 100),
              const SizedBox(height: 20),
              const Text("mxliveoo", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              const Text("Developer Info", style: TextStyle(fontSize: 18, color: Colors.redAccent)),
              const SizedBox(height: 10),
              const Text("Developed by: Sultan Arabi", style: TextStyle(fontSize: 16)),
              const Text("Role: Lettel Developer", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.contact_support),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0088CC)),
                label: const Text("Contact Developer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
