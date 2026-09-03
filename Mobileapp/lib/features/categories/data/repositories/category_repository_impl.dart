import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../../../core/database/sqlite_database.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final SqliteDatabase _databaseHelper;

  CategoryRepositoryImpl({SqliteDatabase? databaseHelper})
      : _databaseHelper = databaseHelper ?? SqliteDatabase.instance;

  @override
  Future<List<Category>> getCategories() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }
}
