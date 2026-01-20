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
const String noticeJsonUrl = "https://raw.githubusercontent.com/v5on/api/main/notice.json"; 
const String telegramUrl = "https://t.me/YourChannel"; 

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
        setState(() {
          noticeMsg = data['notice'] ?? "";
        });
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
        name = nameMatch?.group(1)?.trim() ?? "Unknown Channel";

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
        title: const Text("mxliveoo", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                          crossAxisCount: 4,
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
                                  allChannels: allChannels,
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
    WakelockPlus.enable();
    relatedChannels = widget.allChannels
        .where((c) => c.group == widget.channel.group && c.name != widget.channel.name)
        .toList();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    try {
      // Support for networkUrl handles both HTTP and HTTPS if Cleartext is enabled in Manifest
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        isLive: true, // Optimized for Live TV
        allowedScreenSleep: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text("Error: $errorMessage", style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isError = false;
                      initializePlayer();
                    });
                  },
                  child: const Text("Retry"),
                )
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          backgroundColor: Colors.grey.shade800,
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
          // PLAYER
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          const Text("Stream Error (Offline or Unsupported)", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    )
                  : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                      ? Chewie(controller: _chewieController!)
                      : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
            ),
          ),

          // TELEGRAM BANNER
          GestureDetector(
            onTap: _launchTelegram,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFF0088CC),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.telegram, color: Colors.white),
                  SizedBox(width: 10),
                  Text("JOIN TELEGRAM CHANNEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
          ),

          // RELATED LIST
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text("More Channels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: relatedChannels.length,
              itemBuilder: (ctx, index) {
                final ch = relatedChannels[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(5),
                      image: ch.logo.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(ch.logo), fit: BoxFit.contain) : null,
                    ),
                    child: ch.logo.isEmpty ? const Icon(Icons.tv, size: 20) : null,
                  ),
                  title: Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(ch.group, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  trailing: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
                  onTap: () {
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
      appBar: AppBar(title: const Text("About")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 100, errorBuilder: (c,o,s)=>const Icon(Icons.live_tv, size: 80, color: Colors.red)),
              const SizedBox(height: 20),
              const Text("mxliveoo", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              const Text("Premium Live TV Streaming App", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              const Text("Developer", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const Text("Sultan Arabi (Lettel Developer)", style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
