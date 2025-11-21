import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giphy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GiphyHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GiphyHome extends StatefulWidget {
  const GiphyHome({super.key});

  @override
  State<GiphyHome> createState() => _GiphyHomeState();
}

class _GiphyHomeState extends State<GiphyHome> {

  static const String _apiKey = 'HXeMOLDFQlNjXGyM8q3HbU2FVV6Btutk';

  final List<dynamic> _gifs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _query = '';
  bool _isLoading = false;
  bool _hasMore = true;
  int _limit = 25;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchGifs(isNew: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoading && _hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _fetchGifs();
    }
  }

  Future<void> _fetchGifs({bool isNew = false}) async {
    if (_apiKey == 'HXeMOLDFQlNjXGyM8q3HbU2FVV6Btutk') {
      // Don't attempt network calls without an API key.
      if (mounted) {
        setState(() {
          _hasMore = false;
        });
      }
      return;
    }

    if (_isLoading) return;
    if (isNew) {
      _offset = 0;
      _hasMore = true;
    }

    setState(() {
      _isLoading = true;
    });

    final encodedQuery = Uri.encodeQueryComponent(_query);
    final endpoint = _query.isEmpty ? 'trending' : 'search';
    final url = Uri.parse(
        'https://api.giphy.com/v1/gifs/$endpoint?api_key=$_apiKey&limit=$_limit&offset=$_offset&rating=G${_query.isEmpty ? '' : '&q=$encodedQuery&lang=en'}');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(res.body);
        final List<dynamic> data = body['data'] ?? [];

        setState(() {
          if (isNew) {
            _gifs.clear();
          }
          _gifs.addAll(data);
          _offset += data.length;
          // If fewer than requested returned, no more results.
          _hasMore = data.length >= _limit;
        });
      } else {
        // HTTP error
        debugPrint('Giphy API error: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to load gifs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // debounce for a smooth "update as you type" that doesn't spam the API
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _query = text;
        });
        _fetchGifs(isNew: true);
      }
    });
  }

  Future<void> _onRefresh() async {
    await _fetchGifs(isNew: true);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _onSearchChanged(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search GIFs',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged();
            },
          )
              : null,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giphy'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _gifs.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _gifs.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _gifs.length) {
                      // loader tile
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final gif = _gifs[index] as Map<String, dynamic>;
                    final images = gif['images'] as Map<String, dynamic>?;
                    final fixedWidth = images?['fixed_width'] as Map<String, dynamic>?;
                    final url = fixedWidth?['url'] as String? ?? '';

                    return GestureDetector(
                      onTap: () {
                        final original = images?['original'] as Map<String, dynamic>?;
                        final originalUrl = original?['url'] as String? ?? url;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenGif(url: originalUrl),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.grey.shade300,
                          child: FadeInImage(
                            placeholder:
                            const AssetImage('assets/placeholder.png'),
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                            imageErrorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.broken_image));
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? FloatingActionButton.small(
        onPressed: () {},
        backgroundColor: Colors.blue,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    if (_apiKey == 'HXeMOLDFQlNjXGyM8q3HbU2FVV6Btutk') {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Icon(Icons.warning_amber_rounded, size: 56, color: Colors.blue),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Something went wrong with GIPHY key!',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.search_off, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            _query.isEmpty
                ? 'No GIFs yet. Pull down to refresh.'
                : 'No results for "$_query"',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class FullscreenGif extends StatelessWidget {
  final String url;
  const FullscreenGif({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIF'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60),
          ),
        ),
      ),
    );
  }
}

