import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

const String pexelsApiKey = 'API KEY HERE';

final AppState appState = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await appState.load();

  runApp(const PhotoApp());
}
//emulator->/opt/android-studio/bin/studio
//APP STATE FROM HERE
class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  String? _uid;
  final Map<int, Photo> _saved = {};

  ThemeMode themeMode = ThemeMode.system;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final savedTheme = _prefs!.getString('theme_mode');
    if (savedTheme != null) {
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await setUser(user);
    }
  }

  Future<void> setUser(User? user) async {
    _uid = user?.uid;
    _saved.clear();

    if (_uid != null && _prefs != null) {
      final list = _prefs!.getStringList('saved_$_uid') ?? [];

      for (final item in list) {
        try {
          final photo = Photo.fromJson(jsonDecode(item));
          _saved[photo.id] = photo;
        } catch (_) {}
      }
    }

    notifyListeners();
  }

  bool isSaved(int id) => _saved.containsKey(id);

  int get savedCount => _saved.length;

  List<Photo> get savedPhotos => _saved.values.toList();

  Future<void> toggleSaved(Photo photo) async {
    if (_saved.containsKey(photo.id)) {
      _saved.remove(photo.id);
    } else {
      _saved[photo.id] = photo;
    }

    await _saveToDisk();
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    if (_uid == null || _prefs == null) return;

    final values = _saved.values
        .map((photo) => jsonEncode(photo.toJson()))
        .toList();

    await _prefs!.setStringList('saved_$_uid', values);
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;

    await _prefs?.setString('theme_mode', mode.name);

    notifyListeners();
  }
}

//PHOTO MODEL FROM HERE

class Photo {
  final int id;
  final int width;
  final int height;
  final String imageUrl;
  final String photographer;
  final String originalUrl;

  Photo({
    required this.id,
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.photographer,
    required this.originalUrl,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      width: json['width'],
      height: json['height'],
      imageUrl: json['src']['medium'],
      photographer: json['photographer'],
      originalUrl: json['src']['original'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'width': width,
      'height': height,
      'photographer': photographer,
      'src': {
        'medium': imageUrl,
        'original': originalUrl,
      },
    };
  }
}

//API PART FROM HERE

Future<List<Photo>> fetchPhotos({
  int page = 1,
  String? query,
}) async {
  final uri = query == null
      ? Uri.parse(
          'https://api.pexels.com/v1/curated?per_page=20&page=$page',
        )
      : Uri.parse(
          'https://api.pexels.com/v1/search'
          '?query=${Uri.encodeQueryComponent(query)}'
          '&per_page=20&page=$page',
        );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': pexelsApiKey,
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to load photos');
  }

  final data = jsonDecode(response.body);
  final List photos = data['photos'];

  return photos
      .map((photo) => Photo.fromJson(photo))
      .toList();
}

///APP

class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Photo App',
          themeMode: appState.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

//SPLASH SCREEN

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), _goNext);
  }

  void _goNext() {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) {
          return user == null
              ? const LoginScreen()
              : const MainShell();
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.photo_library_rounded,
                  size: 90,
                ),
                SizedBox(height: 20),
                Text(
                  'Photo App',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//LOGIN

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await appState.setUser(credential.user);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, __) => const MainShell(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;

        if (e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-not-found') {
          errorMessage = 'Incorrect email or password.';
        } else {
          errorMessage = 'Login failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorMessage = 'Login failed. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration:
                          const Duration(milliseconds: 350),
                      pageBuilder: (_, animation, __) =>
                          const SignupScreen(),
                      transitionsBuilder:
                          (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign Up",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//SIGNUP

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';

  Future<void> signup() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        errorMessage = 'Please fill in all fields.';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await appState.setUser(credential.user);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, animation, __) => const MainShell(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;

        if (e.code == 'email-already-in-use') {
          errorMessage = 'An account with this email already exists.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Please enter a valid email address.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak.';
        } else {
          errorMessage = 'Signup failed. Please try again.';
        }
      });
    } catch (_) {
      setState(() {
        isLoading = false;
        errorMessage = 'Signup failed. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signup,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//MAINSHELL

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  final pages = const [
    HomeScreen(),
    SearchScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

//HOME

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController controller = ScrollController();

  final List<Photo> photos = [];

  bool loading = true;
  bool loadingMore = false;
  bool hasError = false;
  bool hasMore = true;

  int page = 1;

  @override
  void initState() {
    super.initState();

    controller.addListener(_scrollListener);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      loading = true;
      hasError = false;
    });

    try {
      final result = await fetchPhotos(page: 1);

      if (!mounted) return;

      setState(() {
        photos
          ..clear()
          ..addAll(result);

        page = 1;
        hasMore = result.length == 20;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore || loading) return;

    setState(() {
      loadingMore = true;
    });

    try {
      final nextPage = page + 1;
      final result = await fetchPhotos(page: nextPage);

      if (!mounted) return;

      setState(() {
        photos.addAll(result);
        page = nextPage;
        hasMore = result.length == 20;
        loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load more photos.'),
        ),
      );
    }
  }

  void _scrollListener() {
    if (controller.position.pixels >
        controller.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (hasError && photos.isEmpty) {
      return _MessageState(
        message: 'Failed to load photos.',
        buttonText: 'Retry',
        onPressed: _loadInitial,
      );
    }

    if (photos.isEmpty) {
      return const _MessageState(
        message: 'No photos found.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: MasonryGridView.builder(
        controller: controller,
        padding: const EdgeInsets.all(10),
        gridDelegate:
            const SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: photos.length + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return PhotoTile(
            photo: photos[index],
            onTap: () => _openDetail(photos[index]),
          );
        },
      ),
    );
  }

  void _openDetail(Photo photo) {
    Navigator.push(
      context,
      _detailRoute(photo),
    );
  }
}

//SEARCH

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController searchController =
      TextEditingController();

  final List<Photo> results = [];

  Timer? debounce;

  bool loading = false;
  bool hasError = false;
  bool searched = false;

  String currentQuery = '';

  @override
  void initState() {
    super.initState();

    searchController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    debounce?.cancel();

    final query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        results.clear();
        searched = false;
        hasError = false;
        loading = false;
      });
      return;
    }

    debounce = Timer(
      const Duration(milliseconds: 500),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    setState(() {
      loading = true;
      hasError = false;
      searched = true;
      currentQuery = query;
    });

    try {
      final result = await fetchPhotos(
        page: 1,
        query: query,
      );

      if (!mounted) return;

      setState(() {
        results
          ..clear()
          ..addAll(result);

        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        hasError = true;
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.removeListener(_onTextChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search photos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!searched) {
      return const Center(
        child: Text('Search for photos'),
      );
    }

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (hasError) {
      return _MessageState(
        message: 'Search failed.',
        buttonText: 'Retry',
        onPressed: () => _search(currentQuery),
      );
    }

    if (results.isEmpty) {
      return const _MessageState(
        message: 'No photos found.',
      );
    }

    return MasonryGridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate:
          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: results.length,
      itemBuilder: (context, index) {
        return PhotoTile(
          photo: results[index],
          onTap: () {
            Navigator.push(
              context,
              _detailRoute(results[index]),
            );
          },
        );
      },
    );
  }
}

//SAVE

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final photos = appState.savedPhotos;

          if (photos.isEmpty) {
            return const _MessageState(
              message: 'No saved photos yet.',
            );
          }

          return MasonryGridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate:
                const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return PhotoTile(
                photo: photos[index],
                onTap: () {
                  Navigator.push(
                    context,
                    _detailRoute(photos[index]),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

//PROFILE

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await appState.setUser(null);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CircleAvatar(
                radius: 45,
                child: Icon(
                  Icons.person,
                  size: 50,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: const Text('Saved photos'),
                  trailing: Text(
                    '${appState.savedCount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_brightness),
                  ),
                ],
                selected: {appState.themeMode},
                onSelectionChanged: (selection) {
                  appState.setTheme(selection.first);
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

//PHOTO TILES

class PhotoTile extends StatefulWidget {
  final Photo photo;
  final VoidCallback onTap;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
  });

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  bool loaded = false;

  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        widget.photo.width / widget.photo.height;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: loaded ? 1 : 0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.photo.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder:
                      (context, child, progress) {
                    if (progress == null) {
                      if (!loaded) {
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              loaded = true;
                            });
                          }
                        });
                      }

                      return child;
                    }

                    return Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: AnimatedBuilder(
                    animation: appState,
                    builder: (context, _) {
                      return GestureDetector(
                        onTap: () async {
                          await appState.toggleSaved(widget.photo);

                          if (!mounted) return;

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              duration:
                                  const Duration(milliseconds: 700),
                              content: Text(
                                appState.isSaved(widget.photo.id)
                                    ? 'Photo saved'
                                    : 'Photo removed',
                              ),
                            ),
                          );
                        },
                        child: AnimatedScale(
                          duration:
                              const Duration(milliseconds: 180),
                          scale: appState.isSaved(widget.photo.id)
                              ? 1.1
                              : 1,
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.55),
                            child: Icon(
                              appState.isSaved(widget.photo.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//PHOTO DETAIL
class PhotoDetailScreen extends StatefulWidget {
  final Photo photo;

  const PhotoDetailScreen({
    super.key,
    required this.photo,
  });

  @override
  State<PhotoDetailScreen> createState() =>
      _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool saveAnimation = false;

  Future<void> _toggleSave() async {
    await appState.toggleSaved(widget.photo);

    if (!mounted) return;

    setState(() {
      saveAnimation = true;
    });

    Future.delayed(
      const Duration(milliseconds: 250),
      () {
        if (mounted) {
          setState(() {
            saveAnimation = false;
          });
        }
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 800),
        content: Text(
          appState.isSaved(widget.photo.id)
              ? 'Photo saved'
              : 'Photo removed',
        ),
      ),
    );
  }

  Future<void> _share() async {
    await Share.share(
      '${widget.photo.originalUrl}\nPhoto by ${widget.photo.photographer}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
      ),
      body: ListView(
        children: [
          Hero(
            tag: 'photo-${widget.photo.id}',
            child: Image.network(
              widget.photo.originalUrl,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photographer',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.photo.photographer,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: appState,
                        builder: (context, _) {
                          return AnimatedScale(
                            duration: const Duration(
                              milliseconds: 180,
                            ),
                            scale: saveAnimation ? 1.15 : 1,
                            child: ElevatedButton.icon(
                              onPressed: _toggleSave,
                              icon: Icon(
                                appState.isSaved(widget.photo.id)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              label: Text(
                                appState.isSaved(widget.photo.id)
                                    ? 'Saved'
                                    : 'Save',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//MESSAGE STATE

class _MessageState extends StatelessWidget {
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _MessageState({
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          if (buttonText != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText!),
            ),
          ],
        ],
      ),
    );
  }
}

//DETAIL ROUTE

PageRouteBuilder _detailRoute(Photo photo) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration:
        const Duration(milliseconds: 300),
    pageBuilder: (_, animation, __) {
      return PhotoDetailScreen(photo: photo);
    },
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}