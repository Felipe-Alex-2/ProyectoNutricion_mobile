import 'package:flutter/material.dart';

import '../../../models/recipe_model.dart';

class NutritionRecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool isDark;
  final Color cardBg, primaryGreen, textPrimary, textSecondary;
  final VoidCallback onDetails;
  const NutritionRecipeCard({
    super.key,
    required this.recipe,
    required this.isDark,
    required this.cardBg,
    required this.primaryGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.65,
                child: recipe.imageUrl?.isNotEmpty == true
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 1000,
                        errorBuilder: (_, _, _) => _placeholder(),
                        loadingBuilder: (context, image, progress) =>
                            progress == null ? image : _placeholder(),
                      )
                    : _placeholder(),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    recipe.category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: primaryGreen),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _meta(
                      Icons.local_fire_department_outlined,
                      '${recipe.calories} kcal',
                    ),
                    _meta(
                      Icons.schedule_outlined,
                      '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                    ),
                    _meta(
                      Icons.person_outline_rounded,
                      '${recipe.servings} porciones',
                    ),
                  ],
                ),
                if (recipe.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    recipe.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, height: 1.45),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Proteínas ${recipe.protein} g',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Carbohidratos ${recipe.carbohydrates} g',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Grasas ${recipe.fats} g',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _placeholder() => Container(
    color: primaryGreen.withValues(alpha: .08),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.restaurant_menu_rounded, size: 44, color: primaryGreen),
        const SizedBox(height: 8),
        Text(
          'Receta de tu nutricionista',
          style: TextStyle(color: primaryGreen, fontSize: 12),
        ),
      ],
    ),
  );
  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: textSecondary),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
    ],
  );
}
