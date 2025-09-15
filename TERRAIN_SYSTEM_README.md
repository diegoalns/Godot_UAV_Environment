# Terrain System Documentation

## Overview

The Terrain System provides a GridMap-based terrain representation for the UAV Simulator using FAA UAS facility data. For each data point in the CSV file, one tile (927m x 702m) is placed at the exact coordinate position, with both mesh selection and height based on the altitude value from the CSV file.

**Key Features:**
- **Direct Placement**: One tile per CSV data point, no complex grid calculations
- **Exact Positioning**: Each tile is centered at its real-world coordinate
- **3D Height Variation**: Tile height directly corresponds to CSV altitude values (0-400m)
- **Consistent Scaling**: Uses the same coordinate conversion as the flight plan system
- **Dual Mapping**: Altitude values determine both mesh selection AND tile height

## System Components

### 1. GridMapManager (`scripts/core/gridmap_manager.gd`)
- **Purpose**: Core logic for loading CSV data and managing GridMap population
- **Key Features**:
  - Loads FAA UAS facility data from `data/Filtered_FAA_UAS_FacilityMap_Data_LGA.csv`
  - Maps altitude values to mesh library items (0→item 1, 50→item 2, 100→item 3, 200→item 4, 300→item 5, 400→item 6)
  - Converts lat/lon coordinates to world positions using same system as FlightPlanManager
  - Places one tile per CSV data point at exact coordinate positions
  - Each tile is 927m x 702m and centered at its coordinate

### 2. TerrainGridMap (`scripts/core/terrain_gridmap.gd`)
- **Purpose**: Scene controller for the terrain GridMap
- **Key Features**:
  - Initializes GridMapManager and GridMap node
  - Provides high-level interface for terrain queries
  - Manages terrain loading status

### 3. Terrain GridMap Scene (`scenes/GridMap/terrain_gridmap.tscn`)
- **Purpose**: Godot scene containing GridMap node with proper configuration
- **Configuration**:
  - Cell size: 702m x 100m x 927m (width x height x depth)
  - Uses `cell_library.meshlib` for mesh resources

## Integration

The terrain system is integrated directly into the VisualizationSystem for optimal performance and proper scaling:

```gdscript
# In VisualizationSystem
var terrain_gridmap: GridMap = null
var gridmap_manager: GridMapManager = null

func setup_terrain():
    # Creates GridMap with proper visual scaling
    terrain_gridmap = GridMap.new()
    terrain_gridmap.cell_size = Vector3(702.0 * visual_scale, 100.0 * visual_scale, 927.0 * visual_scale)
    # Loads and populates terrain data automatically
```

## Usage Examples

### Getting Terrain Altitude at Position
```gdscript
# Get altitude at specific world position
var world_pos = Vector3(1000, 0, 2000)
var altitude = simulation_engine.get_terrain_altitude_at_position(world_pos)
print("Altitude at position: ", altitude)
```

### Getting Terrain Information
```gdscript
# Get terrain system info
var terrain_info = simulation_engine.get_terrain_info()
print("Data points: ", terrain_info.data_points)
print("Grid dimensions: ", terrain_info.grid_dimensions)
print("Coordinate bounds: ", terrain_info.coordinate_bounds)
```

### Checking if Terrain is Ready
```gdscript
# Through simulation engine
if simulation_engine.visualization_system.is_terrain_ready():
    print("Terrain system is fully loaded and ready")
else:
    print("Terrain system is still loading...")

# Or directly through visualization system
if visualization_system.is_terrain_ready():
    print("Terrain ready!")
```

## Altitude Mapping

The system maps CSV altitude values to mesh library items as follows:

| CSV Altitude | Mesh Library Item | Index |
|--------------|-------------------|-------|
| 0            | Item 1            | 0     |
| 50           | Item 2            | 1     |
| 100          | Item 3            | 2     |
| 200          | Item 4            | 3     |
| 300          | Item 5            | 4     |
| 400          | Item 6            | 5     |

## Coordinate System

- **Tile Size**: Each tile is 927m x 702m (depth x width) in world space
- **Tile Height**: Height varies from 0-400m based on CSV altitude values
- **Direct Placement**: Each CSV data point creates one tile at its exact coordinate
- **3D Positioning**: X,Z from lat/lon conversion, Y from CSV altitude
- **Coordinate Conversion**: Uses same lat/lon to world position conversion as FlightPlanManager
  - Origin: Latitude 40.55417343, Longitude -73.99583928
  - Conversion: Standard meters per degree calculation with cosine correction
- **Grid Coordinates**: 
  - X = round(world_x / 702m)
  - Y = altitude (meters)
  - Z = round(world_z / 927m)
- **No Grid Bounds**: No complex grid calculations - each tile is independent

## Data Source

The system reads from `data/Filtered_FAA_UAS_FacilityMap_Data_LGA.csv` with format:
```
CEILING,LATITUDE,LONGITUDE
400,40.55417343,-73.91250593
400,40.55417343,-73.90417259
...
```

## Performance Considerations

- **Loading Time**: Initial terrain loading may take a few seconds depending on data size
- **Memory Usage**: Each terrain tile creates a mesh instance in the GridMap
- **Grid Size**: Grid dimensions are automatically calculated based on coordinate bounds
- **Optimization**: Grid bounds are pre-calculated to minimize unnecessary processing

## Testing

Use the terrain test script (`scripts/utils/terrain_test.gd`) to validate system functionality:

```gdscript
# Attach to a test node and run
extends Node
script = preload("res://scripts/utils/terrain_test.gd")
```

## Troubleshooting

### Common Issues

1. **"Failed to load cell_library.meshlib"**
   - Ensure the mesh library file exists at `resources/Meshs/cell_library.meshlib`
   - Verify the mesh library has at least 6 mesh items

2. **"Failed to open CSV file"**
   - Check that `data/Filtered_FAA_UAS_FacilityMap_Data_LGA.csv` exists
   - Verify file permissions and format

3. **"Terrain not ready"**
   - Wait for terrain loading to complete (check `is_terrain_ready()`)
   - Check console for loading error messages

4. **Incorrect mesh placement**
   - Verify altitude values in CSV match expected mapping
   - Check that mesh library items are properly configured

### Debug Information

Enable debug output by checking console messages during terrain loading:
- GridMapManager initialization messages
- CSV loading progress
- Grid dimension calculations
- Tile placement progress

## Future Enhancements

Potential improvements for the terrain system:

1. **Level of Detail (LOD)**: Implement different mesh resolutions based on distance
2. **Streaming**: Load terrain tiles on-demand for large datasets
3. **Interpolation**: Smooth altitude transitions between tiles
4. **Caching**: Cache processed terrain data for faster subsequent loads
5. **Multiple Data Sources**: Support for additional terrain data formats
