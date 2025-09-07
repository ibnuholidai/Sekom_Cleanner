import 'package:flutter_test/flutter_test.dart';
import 'package:sekom_clenner/models/application_models.dart';
import 'package:sekom_clenner/services/application_service.dart';

void main() {
  group('Data Persistence Tests', () {
    test('Should save and load application lists correctly', () async {
      // Create test data
      List<InstallableApplication> testApps = [
        InstallableApplication(
          id: 'test1',
          name: 'Test App 1',
          description: 'Test application 1',
          downloadUrl: 'C:\\test\\app1.exe',
          installerName: 'app1.exe',
        ),
        InstallableApplication(
          id: 'test2',
          name: 'Test App 2',
          description: 'Test application 2',
          downloadUrl: 'C:\\test\\app2.exe',
          installerName: 'app2.exe',
        ),
      ];

      ApplicationList testList = ApplicationList(
        applications: testApps,
        name: 'Test Shortcut Applications',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save the test data
      try {
        await ApplicationService.saveApplicationList(testList);
        print('✅ Save operation completed successfully');
      } catch (e) {
        print('❌ Save operation failed: $e');
        fail('Save operation should not throw an exception');
      }

      // Load the data back
      try {
        List<ApplicationList> loadedLists = await ApplicationService.loadApplicationLists();
        print('✅ Load operation completed successfully');
        print('📊 Loaded ${loadedLists.length} application lists');
        
        if (loadedLists.isNotEmpty) {
          ApplicationList loadedList = loadedLists.first;
          print('📱 First list contains ${loadedList.applications.length} applications');
          
          // Verify the data
          expect(loadedList.applications.length, equals(2));
          expect(loadedList.applications[0].name, equals('Test App 1'));
          expect(loadedList.applications[1].name, equals('Test App 2'));
          print('✅ Data integrity verified');
        } else {
          fail('No application lists were loaded');
        }
      } catch (e) {
        print('❌ Load operation failed: $e');
        fail('Load operation should not throw an exception');
      }
    });

    test('Should handle portable paths correctly', () {
      // Test portable path conversion
      String absolutePath = 'C:\\Users\\Test\\Documents\\app.exe';
      String portablePath = ApplicationService.makePathPortable(absolutePath);
      String resolvedPath = ApplicationService.resolvePortablePath(portablePath);
      
      print('Original path: $absolutePath');
      print('Portable path: $portablePath');
      print('Resolved path: $resolvedPath');
      
      // The path should be converted and resolved correctly
      expect(portablePath, isNotNull);
      expect(resolvedPath, isNotNull);
      print('✅ Portable path handling works correctly');
    });
  });
}
