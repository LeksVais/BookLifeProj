import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/book_provider.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({Key? key}) : super(key: key);

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  String? _selectedGenre;
  String? _selectedAuthor;
  String? _selectedSort;
  RangeValues _priceRange = const RangeValues(0, 10000);
  
  final List<Map<String, String>> _sortOptions = [
    {'value': '-created_at', 'label': 'Сначала новинки'},
    {'value': 'price', 'label': 'Сначала дешевые'},
    {'value': '-price', 'label': 'Сначала дорогие'},
    {'value': '-views_count', 'label': 'По популярности'},
  ];

  @override
  void initState() {
    super.initState();
    // Загружаем фильтры при открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      if (bookProvider.availableGenres.isEmpty && bookProvider.availableAuthors.isEmpty) {
        bookProvider.loadFilters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: const EdgeInsets.all(16),
      height: screenHeight * 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Фильтры',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort by
                  const Text(
                    'Сортировка',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions.map((sort) {
                      return FilterChip(
                        label: Text(sort['label']!),
                        selected: _selectedSort == sort['value'],
                        onSelected: (selected) {
                          setState(() {
                            _selectedSort = selected ? sort['value'] : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Price range
                  const Text(
                    'Цена',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      '${_priceRange.start.round()} ₽',
                      '${_priceRange.end.round()} ₽',
                    ),
                    onChanged: (values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_priceRange.start.round()} ₽'),
                      Text('${_priceRange.end.round()} ₽'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Genres - реальные данные с сервера
                  const Text(
                    'Жанры',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (bookProvider.isLoadingFilters)
                    const Center(child: CircularProgressIndicator())
                  else if (bookProvider.availableGenres.isEmpty)
                    const Text('Нет доступных жанров', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bookProvider.availableGenres.map((genre) {
                        return FilterChip(
                          label: Text(genre.name),
                          selected: _selectedGenre == genre.name,
                          onSelected: (selected) {
                            setState(() {
                              _selectedGenre = selected ? genre.name : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Authors - реальные данные с сервера
                  const Text(
                    'Авторы',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (bookProvider.isLoadingFilters)
                    const Center(child: CircularProgressIndicator())
                  else if (bookProvider.availableAuthors.isEmpty)
                    const Text('Нет доступных авторов', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bookProvider.availableAuthors.map((author) {
                        return FilterChip(
                          label: Text(author.fullName),
                          selected: _selectedAuthor == author.fullName,
                          onSelected: (selected) {
                            setState(() {
                              _selectedAuthor = selected ? author.fullName : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedGenre = null;
                      _selectedAuthor = null;
                      _selectedSort = null;
                      _priceRange = const RangeValues(0, 10000);
                    });
                  },
                  child: const Text('Сбросить'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    bookProvider.setGenre(_selectedGenre);
                    bookProvider.setAuthor(_selectedAuthor);
                    bookProvider.setSortBy(_selectedSort);
                    bookProvider.setPriceRange(_priceRange.start, _priceRange.end);
                    Navigator.pop(context);
                  },
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}