import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationManagementScreen extends StatefulWidget {
  @override
  _LocationManagementScreenState createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  List<OfficeLocation> _locations = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  
  // Location coordinates
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isAddingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      setState(() => _isLoading = true);
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final locations = await firebaseService.getAllOfficeLocations();
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load locations: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permission denied'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions permanently denied'), backgroundColor: Colors.red),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      });

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = '${place.street}, ${place.locality}, ${place.administrativeArea}';
          _addressController.text = address;
        }
      } catch (e) {
        print('Could not get address: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location captured successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addLocation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture location coordinates'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      setState(() => _isAddingLocation = true);
      
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      final location = OfficeLocation(
        id: '', // Will be set by Firebase
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        radiusInMeters: double.parse(_radiusController.text),
        description: _descriptionController.text.trim(),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firebaseService.addOfficeLocation(location);
      
      // Clear form
      _nameController.clear();
      _addressController.clear();
      _descriptionController.clear();
      _radiusController.text = '100';
      _selectedLatitude = null;
      _selectedLongitude = null;
      
      // Reload locations
      await _loadLocations();
      
      // Close the dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location added successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add location: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isAddingLocation = false);
    }
  }

  Future<void> _deleteLocation(OfficeLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Location'),
        content: Text('Are you sure you want to delete "${location.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.deleteOfficeLocation(location.id);
      await _loadLocations();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location deleted successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete location: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Office Locations'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_location),
            onPressed: () => _showAddLocationDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No office locations configured',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add your first office location to enable geofencing',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddLocationDialog(),
                        icon: Icon(Icons.add_location),
                        label: Text('Add First Location'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLocations,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _locations.length,
                    itemBuilder: (context, index) {
                      final location = _locations[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Icon(Icons.location_on, color: Colors.white),
                          ),
                          title: Text(
                            location.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(location.address),
                              SizedBox(height: 4),
                              Text(
                                'Radius: ${location.radiusInMeters}m • ${location.description.isNotEmpty ? location.description : 'No description'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Edit'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red),
                                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                // TODO: Implement edit functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Edit functionality coming soon!'), backgroundColor: Colors.orange),
                                );
                              } else if (value == 'delete') {
                                _deleteLocation(location);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showAddLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Office Location'),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6, // Limit height
          child: Form(
            key: _formKey,
            child: SingleChildScrollView( // Make it scrollable
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'e.g., Main Office, Branch Office',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter location name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address *',
                    hintText: 'Full address of the office',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1, // Reduced from 2 to 1
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _radiusController,
                  decoration: InputDecoration(
                    labelText: 'Geofence Radius (meters) *',
                    hintText: 'e.g., 100',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter radius';
                    }
                    final radius = double.tryParse(value);
                    if (radius == null || radius <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: Icon(Icons.my_location),
                        label: Text('Get Current Location'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (_selectedLatitude != null && _selectedLongitude != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Location captured: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAddingLocation ? null : _addLocation,
            child: _isAddingLocation
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Add Location'),
          ),
        ],
      ),
    );
  }
}
