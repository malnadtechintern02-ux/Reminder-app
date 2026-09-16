import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories({bool forceSync = false});
  Future<void> syncCategories();
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
}
