import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories({bool forceSync = false});
  Future<void> syncCategories();
}
