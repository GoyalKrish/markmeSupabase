# Flutter Development Guidelines

## Core Development Principles

### 1. Modularity

- **Component Reusability**: Design all components to be reusable across the application.
  - Implement stateless widgets where possible to maximize reusability.
  - Use parameterization for customizable components.
  - Maintain consistent naming conventions for all reusable components.

- **Single Source of Truth**: Changes to a component should reflect everywhere it's used.
  - Use state management solutions (Provider, Riverpod, Bloc) to maintain synchronized state.
  - Avoid duplicating component logic in multiple places.
  - Implement a component library or design system for UI elements.

- **Folder Structure**:
  ```
  lib/
  ├── components/       # Reusable UI components
  ├── screens/          # App screens
  ├── models/           # Data models
  ├── services/         # Business logic and API services
  ├── utils/            # Helper functions and constants
  ├── state/            # State management
  └── main.dart
  ```

### 2. Clarity and Functionality

- **Code Readability**:
  - Follow Flutter style guide and consistent formatting.
  - Use descriptive names for variables, functions, and classes.
  - Add comments for complex logic or business rules.

- **Feature Implementation**:
  - Create a ticket/task for each new feature with clear requirements.
  - Implement features exactly as specified in requirements.
  - Document any deviations or technical limitations.
  - Propose enhancements as separate items, but do not implement without approval.

- **Documentation**:
  - Document all public APIs and complex components.
  - Maintain a README for each module explaining its purpose and usage.
  - Include examples for non-obvious implementations.

### 3. Independence and Non-interference

- **Feature Isolation**:
  - Design features to be self-contained whenever possible.
  - Use interfaces and abstractions to reduce direct dependencies.
  - Implement proper error handling to prevent cascading failures.

- **Testing Strategy**:
  - Write unit tests for all business logic.
  - Implement widget tests for UI components.
  - Create integration tests for critical user flows.
  - Run the full test suite before merging new features.

- **Version Control Practices**:
  - Create feature branches for all new development.
  - Use meaningful commit messages that explain the why, not just the what.
  - Perform code reviews before merging to main/master.
  - Handle merge conflicts carefully to prevent feature regression.

### 4. Supabase Integration

- **Database Connection**:
  - Centralize Supabase client initialization and configuration.
  - Use environment variables for Supabase URL and key.
  - Implement connection status monitoring and error handling.

- **Data Models**:
  - Create typed models that match Supabase table schemas.
  - Implement `fromJson` and `toJson` methods for all models.
  - Use immutable data classes when appropriate.

- **Service Layer**:
  - Create dedicated service classes for Supabase operations.
  - Implement CRUD operations through repository pattern.
  - Handle offline operations with appropriate caching strategy.

- **Authentication**:
  - Utilize Supabase Auth for user management.
  - Implement secure token storage and refresh logic.
  - Create middleware for authenticated API routes.

- **Realtime Updates**:
  - Use Supabase realtime subscriptions for live data updates.
  - Implement proper subscription cleanup to prevent memory leaks.
  - Add error handling for subscription interruptions.

## Cursor-Specific Guidelines

### IDE Setup

- **Extensions**:
  - Flutter and Dart extensions
  - Code formatting plugins
  - Linting tools

- **Code Generation**:
  - Configure snippets for common Flutter patterns.
  - Set up templates for new components, screens, and services.

- **Auto-completion**:
  - Optimize auto-imports for project structure.
  - Configure code actions for common refactoring tasks.

### Code Review Process

1. **Automated Checks**:
   - Run Flutter analysis tools before submitting PR.
   - Verify test coverage for new code.
   - Ensure formatting consistency.

2. **Manual Review**:
   - Verify component reusability and modularity.
   - Check for potential conflicts with existing features.
   - Confirm Supabase integration follows established patterns.

3. **Feature Verification**:
   - Test feature on multiple screen sizes.
   - Verify offline behavior if applicable.
   - Check performance impact.

## Implementation Examples

### Reusable Button Component

```dart
// lib/components/custom_button.dart
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final bool isLoading;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.style,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style ?? Theme.of(context).elevatedButtonTheme.style,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(text),
    );
  }
}
```

### Supabase Service Example

```dart
// lib/services/supabase_service.dart
class SupabaseService {
  final SupabaseClient _client;
  
  SupabaseService(this._client);
  
  // Generic fetch method with error handling
  Future<List<T>> fetchData<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    List<String>? columns,
    String? queryFilter,
    dynamic filterValue,
  }) async {
    try {
      var query = _client.from(table).select(columns?.join(',') ?? '*');
      
      if (queryFilter != null && filterValue != null) {
        query = query.filter(queryFilter, 'eq', filterValue);
      }
      
      final response = await query.execute();
      
      if (response.error != null) {
        throw Exception(response.error!.message);
      }
      
      return (response.data as List)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Log error and rethrow or handle appropriately
      print('Error fetching data from $table: $e');
      rethrow;
    }
  }
  
  // Additional methods for create, update, delete, etc.
}
```

## Feature Addition Workflow

1. **Feature Request**:
   - Document requirements clearly.
   - Define acceptance criteria.
   - Identify potential reuse of existing components.

2. **Implementation Plan**:
   - Create required models and services.
   - Implement UI components.
   - Connect to Supabase backend.
   - Add tests.

3. **Review and Approval**:
   - Demonstrate feature to stakeholders.
   - Propose any enhancements or modifications.
   - Get explicit approval before implementing additional features.

## Maintenance Guidelines

- **Dependency Updates**:
  - Regularly update Flutter and package dependencies.
  - Test thoroughly after updates.
  - Document breaking changes and required migrations.

- **Performance Monitoring**:
  - Use Flutter DevTools to identify performance bottlenecks.
  - Monitor Supabase query performance.
  - Implement performance tests for critical user flows.

- **Technical Debt**:
  - Allocate time for refactoring in each development cycle.
  - Document technical debt and prioritize resolution.
  - Use TODO comments with ticket references for future improvements.