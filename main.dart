import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/catalogo': (context) => const CatalogoScreen(),
        '/admin': (context) => const AdminScreen(),
      },
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
          return const CatalogoScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// ==================== PANTALLA DE LOGIN / REGISTRO ====================
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
                    _isLogin ? 'Bienvenido a Cine Clásico' : 'Crear Cuenta',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_isLogin)
                    const Text(
                      'Inicia sesión para disfrutar del catálogo',
                      style: TextStyle(color: Colors.grey),
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

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    final url = Uri.https(
      baseUrl,
      '/3/movie/popular',
      {
        'api_key': apiKey,
        'language': 'es-ES',
        'page': page.toString(),
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

  Future<MovieDetail> getMovieDetails(int movieId) async {
    final url = Uri.https(
      baseUrl,
      '/3/movie/$movieId',
      {
        'api_key': apiKey,
        'language': 'es-ES',
      },
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return MovieDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener detalles: ${response.statusCode}');
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

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    required this.overview,
    required this.voteAverage,
    this.releaseDate,
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
    );
  }
}

class MovieDetail extends Movie {
  final String? director;
  final List<String> genres;

  MovieDetail({
    required super.id,
    required super.title,
    super.posterPath,
    required super.overview,
    required super.voteAverage,
    super.releaseDate,
    this.director,
    this.genres = const [],
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> genreList = json['genres'] ?? [];
    final genres = genreList.map((g) => g['name'] as String).toList();
    
    return MovieDetail(
      id: json['id'],
      title: json['title'] ?? 'Sin título',
      posterPath: json['poster_path'],
      overview: json['overview'] ?? 'Sin descripción disponible',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'],
      genres: genres,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'overview': overview,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'year': year,
      'genres': genres,
      'director': director,
    };
  }

  factory MovieDetail.fromMap(Map<String, dynamic> map) {
    return MovieDetail(
      id: map['id'],
      title: map['title'],
      posterPath: map['posterPath'],
      overview: map['overview'],
      voteAverage: (map['voteAverage'] ?? 0).toDouble(),
      releaseDate: map['releaseDate'],
      genres: List<String>.from(map['genres'] ?? []),
      director: map['director'],
    );
  }
}

// ==================== PANTALLA DE CATÁLOGO ====================
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  List<Movie> movies = [];
  bool isLoading = true;
  String errorMessage = '';
  late TMDBService tmdbService;

  @override
  void initState() {
    super.initState();
    tmdbService = TMDBService();
    loadMovies();
  }

  Future<void> loadMovies() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final fetchedMovies = await tmdbService.getPopularMovies();
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
    Navigator.pushReplacementNamed(context, '/');
  }

  void _goToAdmin() {
    Navigator.pushNamed(context, '/admin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          '🎬 Catálogo de Películas',
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
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: _goToAdmin,
            tooltip: 'Administración',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade100, Colors.deepPurple.shade50],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (movies.isEmpty) {
      return const Center(
        child: Text('No hay películas disponibles'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return GestureDetector(
          onTap: () => _showMovieDetails(movie.id),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: movie.posterPath != null
                        ? Image.network(
                            movie.posterUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 50),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie, size: 50),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.year,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMovieDetails(int movieId) async {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<MovieDetail>(
          future: tmdbService.getMovieDetails(movieId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('Error: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            }

            final movie = snapshot.data!;
            return AlertDialog(
              title: Text(movie.title),
              content: SizedBox(
                width: 350,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie.posterPath != null)
                        Center(
                          child: Image.network(
                            movie.posterUrl,
                            height: 200,
                            errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 100),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.calendar_today, 'Año', movie.year),
                      const SizedBox(height: 5),
                      _buildDetailRow(Icons.theater_comedy, 'Género', movie.genres.join(', ')),
                      const SizedBox(height: 5),
                      _buildDetailRow(Icons.star, 'Calificación', '${movie.voteAverage.toStringAsFixed(1)}/10'),
                      const SizedBox(height: 10),
                      const Text(
                        'Sinopsis:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        movie.overview,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.deepPurple),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value.isNotEmpty ? value : 'No disponible')),
      ],
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

// ==================== PANTALLA DE ADMINISTRACIÓN MEJORADA ====================
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _anoController = TextEditingController();
  final _directorController = TextEditingController();
  final _generoController = TextEditingController();
  final _sinopsisController = TextEditingController();
  final _imagenUrlController = TextEditingController();
  
  List<MovieDetail> peliculasPersonalizadas = [];
  List<MovieDetail> peliculasFiltradas = [];
  String _busqueda = '';
  int? _editandoId;
  bool _isLoading = false;
  
  // Lista de géneros predefinidos
  final List<String> _generosDisponibles = [
    'Acción', 'Aventura', 'Comedia', 'Drama', 'Terror', 
    'Ciencia Ficción', 'Romance', 'Musical', 'Suspenso', 
    'Animación', 'Documental', 'Fantasía', 'Western'
  ];
  
  // Años disponibles (1900 - año actual)
  late List<String> _anosDisponibles;

  @override
  void initState() {
    super.initState();
    _anosDisponibles = List.generate(
      DateTime.now().year - 1899,
      (i) => (1900 + i).toString(),
    ).reversed.toList();
    _cargarPeliculasLocales();
  }

  Future<void> _cargarPeliculasLocales() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_movies')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      peliculasPersonalizadas = snapshot.docs.map((doc) {
        final data = doc.data();
        return MovieDetail(
          id: data['id'],
          title: data['title'],
          posterPath: data['posterPath'],
          overview: data['overview'],
          voteAverage: (data['voteAverage'] ?? 0).toDouble(),
          releaseDate: data['releaseDate'],
          director: data['director'],
          genres: List<String>.from(data['genres'] ?? []),
        );
      }).toList();
      _filtrarPeliculas();
      _isLoading = false;
    });
  }

  void _filtrarPeliculas() {
    if (_busqueda.isEmpty) {
      peliculasFiltradas = List.from(peliculasPersonalizadas);
    } else {
      peliculasFiltradas = peliculasPersonalizadas.where((p) {
        return p.title.toLowerCase().contains(_busqueda.toLowerCase()) ||
               (p.director?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false);
      }).toList();
    }
    setState(() {});
  }

  Future<void> _guardarPelicula() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Validar URL de imagen (si se proporcionó)
      String? imagenUrl = _imagenUrlController.text.trim();
      if (imagenUrl.isNotEmpty && !_validarUrlImagen(imagenUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ La URL de la imagen no parece válida')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final pelicula = MovieDetail(
        id: _editandoId ?? DateTime.now().millisecondsSinceEpoch,
        title: _tituloController.text,
        posterPath: imagenUrl.isNotEmpty ? imagenUrl : null,
        overview: _sinopsisController.text,
        voteAverage: 0,
        releaseDate: _anoController.text,
        director: _directorController.text,
        genres: _generoController.text.split(',').map((g) => g.trim()).toList(),
      );

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('custom_movies')
          .doc(pelicula.id.toString());

      if (_editandoId != null) {
        await docRef.update(pelicula.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✏️ Película actualizada correctamente')),
        );
      } else {
        await docRef.set({
          ...pelicula.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Película agregada correctamente')),
        );
      }

      _limpiarFormulario();
      await _cargarPeliculasLocales();
      setState(() => _isLoading = false);
    }
  }

  bool _validarUrlImagen(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Future<void> _eliminarPelicula(MovieDetail pelicula) async {
    // Diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar "${pelicula.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('custom_movies')
          .doc(pelicula.id.toString())
          .delete();

      await _cargarPeliculasLocales();
      
      // Mostrar opción de deshacer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ "${pelicula.title}" eliminada'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => _restaurarPelicula(pelicula),
          ),
        ),
      );
      
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restaurarPelicula(MovieDetail pelicula) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_movies')
        .doc(pelicula.id.toString())
        .set({
          ...pelicula.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });
    
    await _cargarPeliculasLocales();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('↩️ Película restaurada')),
    );
  }

  void _editarPelicula(MovieDetail pelicula) {
    setState(() {
      _editandoId = pelicula.id;
      _tituloController.text = pelicula.title;
      _anoController.text = pelicula.year;
      _directorController.text = pelicula.director ?? '';
      _generoController.text = pelicula.genres.join(', ');
      _sinopsisController.text = pelicula.overview;
      _imagenUrlController.text = pelicula.posterPath ?? '';
    });
    
    // Scroll al formulario
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _limpiarFormulario() {
    _editandoId = null;
    _tituloController.clear();
    _anoController.clear();
    _directorController.clear();
    _generoController.clear();
    _sinopsisController.clear();
    _imagenUrlController.clear();
    setState(() {});
  }

  void _mostrarVistaPreviaImagen() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Vista previa de la imagen'),
            ),
            Image.network(
              _imagenUrlController.text,
              height: 300,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetallesPelicula(MovieDetail pelicula) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pelicula.title),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pelicula.posterPath != null)
                Center(
                  child: Image.network(
                    pelicula.posterUrl,
                    height: 150,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 100),
                  ),
                ),
              const SizedBox(height: 10),
              Text('Año: ${pelicula.year}'),
              Text('Director: ${pelicula.director ?? "No especificado"}'),
              Text('Género: ${pelicula.genres.join(", ")}'),
              const SizedBox(height: 10),
              const Text('Sinopsis:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(pelicula.overview),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          '⚙️ Administración de Películas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Volver al catálogo',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade100, Colors.deepPurple.shade50],
          ),
        ),
        child: Row(
          children: [
            // Panel izquierdo - Formulario
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_editandoId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'EDITANDO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _editandoId != null ? 'Editar Película' : 'Agregar Nueva Película',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Título
                          TextFormField(
                            controller: _tituloController,
                            decoration: const InputDecoration(
                              labelText: 'Título',
                              prefixIcon: Icon(Icons.title),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Ingrese el título' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          // Año (Dropdown)
                          DropdownButtonFormField<String>(
                            value: _anoController.text.isNotEmpty ? _anoController.text : null,
                            decoration: const InputDecoration(
                              labelText: 'Año',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            items: _anosDisponibles.map((ano) {
                              return DropdownMenuItem(value: ano, child: Text(ano));
                            }).toList(),
                            onChanged: (value) => _anoController.text = value!,
                            validator: (v) => v == null ? 'Seleccione el año' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          // Director
                          TextFormField(
                            controller: _directorController,
                            decoration: const InputDecoration(
                              labelText: 'Director',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Ingrese el director' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          // Género
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _generoController,
                                decoration: const InputDecoration(
                                  labelText: 'Género (separar con comas)',
                                  prefixIcon: Icon(Icons.theater_comedy),
                                  border: OutlineInputBorder(),
                                  helperText: 'Ej: Acción, Drama, Comedia',
                                ),
                                validator: (v) => v?.isEmpty == true ? 'Ingrese al menos un género' : null,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _generosDisponibles.map((genero) {
                                  return ActionChip(
                                    label: Text(genero),
                                    onPressed: () {
                                      final actual = _generoController.text;
                                      if (actual.isEmpty) {
                                        _generoController.text = genero;
                                      } else if (!actual.contains(genero)) {
                                        _generoController.text = '$actual, $genero';
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          // Sinopsis
                          TextFormField(
                            controller: _sinopsisController,
                            decoration: const InputDecoration(
                              labelText: 'Sinopsis',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            validator: (v) => v?.isEmpty == true ? 'Ingrese la sinopsis' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          // URL de Imagen con vista previa
                          TextFormField(
                            controller: _imagenUrlController,
                            decoration: InputDecoration(
                              labelText: 'URL de la imagen',
                              prefixIcon: const Icon(Icons.image),
                              border: const OutlineInputBorder(),
                              suffixIcon: _imagenUrlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.preview),
                                      onPressed: () => _mostrarVistaPreviaImagen(),
                                    )
                                  : null,
                            ),
                          ),
                          if (_imagenUrl
