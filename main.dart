import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Generado con flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Películas Clásicas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // Cambiar a AuthWrapper
    );
  }
}

// ==================== AUTH WRAPPER ====================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const MyHomePage();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ==================== PANTALLA DE LOGIN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade300],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie, size: 60, color: Colors.deepPurple),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(_isLogin ? 'Ingresar' : 'Registrarse'),
                        ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? '¿No tienes cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Inicia sesión',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SERVICIO DE TMDB ====================
class TMDBService {
  static const String apiKey = 'TU_API_KEY_AQUI'; // 🔑 REEMPLAZA CON TU API KEY
  static const String baseUrl = 'api.themoviedb.org';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  Future<List<Movie>> getMoviesByCategory(String category, {int page = 1}) async {
    String endpoint;
    switch (category) {
      case 'Acción':
        endpoint = '/3/discover/movie';
        break;
      case 'Drama':
        endpoint = '/3/discover/movie';
        break;
      case 'Musicales':
        endpoint = '/3/discover/movie';
        break;
      default:
        endpoint = '/3/movie/popular';
    }

    final url = Uri.https(
      baseUrl,
      endpoint,
      {
        'api_key': apiKey,
        'language': 'es-ES',
        'page': page.toString(),
        if (category == 'Acción') 'with_genres': '28',
        if (category == 'Drama') 'with_genres': '18',
        if (category == 'Musicales') 'with_genres': '10402',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Movie>> searchMovies(String query) async {
    final url = Uri.https(
      baseUrl,
      '/3/search/movie',
      {
        'api_key': apiKey,
        'query': query,
        'language': 'es-ES',
      },
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'];
      return results.map((json) => Movie.fromJson(json)).toList();
    } else {
      throw Exception('Error al buscar: ${response.statusCode}');
    }
  }
}

// ==================== MODELO DE PELÍCULA ====================
class Movie {
  final int id;
  final String title;
  final String? posterPath;
  final String overview;
  final double voteAverage;
  final String? releaseDate;
  final List<int> genreIds;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    required this.overview,
    required this.voteAverage,
    this.releaseDate,
    this.genreIds = const [],
  });

  String get posterUrl {
    if (posterPath == null) return '';
    return '${TMDBService.imageBaseUrl}$posterPath';
  }

  String get year {
    if (releaseDate == null || releaseDate!.length < 4) return 'Desconocido';
    return releaseDate!.substring(0, 4);
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? 'Sin título',
      posterPath: json['poster_path'],
      overview: json['overview'] ?? 'Sin descripción disponible',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'],
      genreIds: List<int>.from(json['genre_ids'] ?? []),
    );
  }

  // Convertir a mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'overview': overview,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'year': year,
      'posterUrl': posterUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Crear desde Firestore
  factory Movie.fromFirestore(Map<String, dynamic> data) {
    return Movie(
      id: data['id'],
      title: data['title'],
      posterPath: data['posterPath'],
      overview: data['overview'],
      voteAverage: (data['voteAverage'] ?? 0).toDouble(),
      releaseDate: data['releaseDate'],
    );
  }
}

// ==================== PANTALLA PRINCIPAL ====================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String selectedOption = 'Todas las películas';
  List<Movie> movies = [];
  bool isLoading = true;
  String errorMessage = '';
  late TMDBService tmdbService;
  Set<int> favoriteIds = {};

  // Películas clásicas locales (fallback)
  final List<Map<String, String>> localMovies = const [
    {'title': 'Grease', 'year': '1978', 'cast': 'John Travolta, Olivia Newton-John'},
    {'title': 'Scarface', 'year': '1983', 'cast': 'Al Pacino'},
    {'title': 'Pulp Fiction', 'year': '1994', 'cast': 'John Travolta, Uma Thurman'},
    {'title': 'Amadeus', 'year': '1984', 'cast': 'F. Murray Abraham'},
    {'title': 'Ran', 'year': '1985', 'cast': 'Akira Kurosawa'},
    {'title': 'The Mask of Zorro', 'year': '1998', 'cast': 'Anthony Hopkins, Antonio Banderas'},
  ];

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    loadMovies();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .get();
    
    setState(() {
      favoriteIds = snapshot.docs.map((doc) => doc['id'] as int).toSet();
    });
  }

  Future<void> toggleFavorite(Movie movie) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para guardar favoritos')),
      );
      return;
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(movie.id.toString());

    if (favoriteIds.contains(movie.id)) {
      await favoriteRef.delete();
      setState(() {
        favoriteIds.remove(movie.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${movie.title} removida de favoritos')),
      );
    } else {
      await favoriteRef.set(movie.toFirestore());
      setState(() {
        favoriteIds.add(movie.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${movie.title} añadida a favoritos')),
      );
    }
  }

  Future<void> loadMovies() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final fetchedMovies = await tmdbService.getMoviesByCategory(selectedOption);
      setState(() {
        movies = fetchedMovies;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> searchMovies(String query) async {
    if (query.isEmpty) {
      await loadMovies();
      return;
    }

    setState(() => isLoading = true);

    try {
      final results = await tmdbService.searchMovies(query);
      setState(() {
        movies = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showFavorites() {
    showDialog(
      context: context,
      builder: (context) => const FavoritesDialog(),
    );
  }

  Widget get leftColumn {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mensaje de bienvenida con usuario
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading ? 'Cargando películas...' : '¡Bienvenido a Cine Clásico!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: _showFavorites,
                tooltip: 'Mis favoritos',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        const Text(
          'Filtrar por categoría:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: selectedOption,
          isExpanded: true,
          onChanged: (String? newValue) {
            setState(() {
              selectedOption = newValue!;
            });
            loadMovies();
          },
          items: <String>['Todas las películas', 'Acción', 'Drama', 'Musicales']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 30),
        
        const Text(
          'Películas destacadas:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _buildMovieList(),
        ),
      ],
    );
  }

  Widget _buildMovieList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 50, color: Colors.red),
            const SizedBox(height: 10),
            Text('Error: $errorMessage'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: loadMovies,
              child: const Text('Reintentar con API'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  isLoading = false;
                  errorMessage = '';
                  movies = [];
                });
              },
              child: const Text('Usar lista local'),
            ),
          ],
        ),
      );
    }

    if (movies.isEmpty) {
      return ListView(
        children: localMovies.map((movie) {
          return ListTile(
            leading: const Icon(Icons.local_movies),
            title: Text('${movie['title']} (${movie['year']})'),
            subtitle: Text(movie['cast'] ?? ''),
          );
        }).toList(),
      );
    }

    return ListView.builder(
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final isFavorite = favoriteIds.contains(movie.id);
        
        return ListTile(
          leading: movie.posterPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    movie.posterUrl,
                    width: 45,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 40),
                  ),
                )
              : const Icon(Icons.local_movies, size: 40),
          title: Text(
            movie.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.year),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(movie.voteAverage.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: () => toggleFavorite(movie),
          ),
          onTap: () => _showMovieDetails(movie),
        );
      },
    );
  }

  void _showMovieDetails(Movie movie) {
    final isFavorite = favoriteIds.contains(movie.id);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(movie.title)),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
              ),
              onPressed: () {
                Navigator.pop(context);
                toggleFavorite(movie);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (movie.posterPath != null)
                Center(
                  child: Image.network(
                    movie.posterUrl,
                    height: 150,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 100),
                  ),
                ),
              const SizedBox(height: 10),
              Text('Año: ${movie.year}'),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${movie.voteAverage.toStringAsFixed(1)}/10'),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Sinopsis:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                movie.overview,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget get mainImage {
    return Container(
      width: 400,
      height: 600,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        image: const DecorationImage(
          image: AssetImage('assets/Peliculas_clasicas.webp'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 60, color: Colors.white70),
              const SizedBox(height: 10),
              const Text(
                'Películas Clásicas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'El arte que trasciende el tiempo',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (!isLoading && movies.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🎬 ${movies.length} películas cargadas',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              if (favoriteIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '❤️ ${favoriteIds.length} favoritas',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          '🎬 Películas Clásicas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadMovies,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.deepPurple.shade50,
            ],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 40, 0, 30),
            height: 600,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 440, child: leftColumn),
                  mainImage,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String query = '';
        return AlertDialog(
          title: const Text('Buscar película'),
          content: TextField(
            onChanged: (value) => query = value,
            decoration: const InputDecoration(
              hintText: 'Ej: Pulp Fiction, Grease...',
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (query.isNotEmpty) {
                  searchMovies(query);
                }
              },
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }
}

// ==================== DIÁLOGO DE FAVORITOS ====================
class FavoritesDialog extends StatelessWidget {
  const FavoritesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return AlertDialog(
        title: const Text('Inicia sesión'),
        content: const Text('Debes iniciar sesión para ver tus favoritos'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Mis Películas Favoritas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('favorites')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No tienes películas favoritas aún'),
                    );
                  }

                  final favorites = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final data = favorites[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: data['posterPath'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '${TMDBService.imageBaseUrl}${data['posterPath']}',
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                                ),
                              )
                            : const Icon(Icons.movie),
                        title: Text(data['title']),
                        subtitle: Text(data['year'] ?? 'Año desconocido'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await favorites[index].reference.delete();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
