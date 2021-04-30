This repo provides the methods required to recreate the dataset of walking and hiking tracks in the walking speeds paper.
For simple replication of the dataset, the supplied dataset should be used, and the Ordnance Survey elevation data must be added

For full recreation of the methods involved, the full guide should be followed.  
Note: this is not recommended as the ```find_breaks``` method takes a very long time to run  
(~1 week on 2018 MacBook Air, 1.6 GHz Dual-Core Intel Core i5, 8 GB 2133 MHz LPDDR3)

To replicate the dataset for use in future work, you can skip some steps, and instead use the included
Hikr.csv, and OSM.csv merged files


- Data Access
    - OS Terrain
    - National Grid Squares
- Conda Environment
- Config file

- For Full Replication
    - OS grid setup
    - Reading gpx files
    
- Adding terrain information
- Merge and Filter


Due to licensing requirements, the following datasets are not available for public download and require

#### Required: OS Terrain 5 DTM

This is the Digital Terrain Map containing elevation data required for calculating both walking and hill slope angles.

It is available for download under an Educational License from Digimap.

The number of tiles available for download from the 

The Digimap Bulk Download Request form can be found here:
https://goo.gl/FxyyFs

Scotland coverage, in ASC format

The list of 100 km National Grid tiles used in the work is below:

                HP
             HT HU
       HW HX HY HZ
    NA NB NC ND   
    NF NG NH NJ NK
    NL NM NN NO
       NR NS NT NU
       NW NX NY 

Note that the NY tile may not contain all constituent 5km tiles, as the majority of the NY region covers England. The following NY tiles are sufficient to include all data for Scotland, however having more files will not cause issues

    09 19 29 39 49 59 69
    08 18 28 38 48 58 
    07 17 27 37 47 
    06 16 26 36 

#### Required for full replication: OS National grid squares

GB National Grid Squares
Format: Shapefile
Layers: 100km National Grid Squares \
        10km National Grid Squares
        
        
# Conda Environment

To replicate the data, the   

Create a conda environment and install python, qgis, click and pandas

```Bash
conda create -n [environment_name] python=3.8
conda activate [environment_name]
conda install -c conda-forge qgis=3.18.2
conda install -c conda-forge click=7.1.2
conda install -c conda-forge pandas=1.2.4
```

If recreating hikr data from scratch, scrapy is also required:
```Bash
conda install -c conda-forge scrapy=2.1.4
```

Install this package locally:

```Bash
pip install .
```


### Config file

The file config.yaml contained within this package is used as the configuration file, and should be edited to point to the correct file locations

- ***qgis_path***
: The path of the qgis executable within the conda environment  
On MacOS: [environment_path]/QGIS.app/Contents/MacOS
- **filetype** 
: should be set to either *osm* or *hikr* depending on which data type is being read 
- **data**
  - **os_grid_folder**
  : Folder containing OS National grid files 
    ```
    .
    ├── os_grid_folder
        └── 10km_grid_region.shp
        └── 100km_grid_region.shp
         ⋮
    ```
  - **GPS_files**
    - **hikr**
      - **website**
      : address of first page of results to parse for GPS data  
      It should not need to be altered from https://www.hikr.org/region518/ped/?gps=1
      - **folder**
      : Location to store json file containing hikr data links
      - **name**
      : Filename of json file containing hikr data links
    - **osm**
      - **folder**
      : Location of OpenStreetMap tracks to be read
  - **terrain**:
    - **DTM_folder**
    : Top level folder containing DTM files e.g 
        ```
        .
        ├── DTM_folder
            └── hp
                └── HP40NE.asc
                └── HP40NE.prj
                └── HP40NE.gml
                └── Metadata_HP40NE.xml
                 ⋮
            └── ht
             ⋮
        ```
    - **DTM_resolution**
    : Resolution of DTM data (default is 5)  
- **conditions**
  - **data_filter**
  : Whether to run initial filter on OSM data to remove files which are not in scope (not required but speeds up processing), should be set to False if already filtered dataset
  - **in_scope_folder**
  : location to copy in-scope .gpx files 
- **output** 
  - **gpkg_folder**
  : Location to save gpkg output files 
  - **name_root**
  : Name stem for gpkg files, indexes are automatically added for each new track & segment, e.g Data0_001 
  - **merged_folder**
  : location to save merged .gpkg and .csv files 
  - **merged_name**
  : file name to save merged .gpkg and .csv files
  
#### OS grid setup
Run OSgrid_reduce to reduce OS National Grid Tiles down to Scotland only
```Bash
OSgrid_reduce -c config.yaml
```

## Replication

#### Data Collection:
The scrape script will create a .json file containing the gpx track filepaths
```Bash
scrape -c config.yaml
```
Download OSM GPS files from 
http://zverik.openstreetmap.ru/gps/files/extracts/europe/great_britain/scotland.tar.xz



Read the .json file [filetype = hikr], or folder [filetype = osm], and import gpx files as .gpkg files.
These files will be saved to the config [output][gpkg_folder] location

If running with osm data and filter = True, this will also save all of the valid gpx files to in_scope_folder
```Bash
run_gpx_importer -c config.yaml
```

Find breaks in the GPS tracks. This script will add an 'OnBreak' attribute to the gpkg file  
Note that this script will delete files which are clearly not walking tracks (median speed > 10km/h), 
or don't contain enough data to be useful (distance < 250m or duration < 2:30)

```Bash
find_breaks -c config.yaml
```
Merge the gpkg tracks into a single dataset. This will take all of the files in [output][gpkg_folder] 
and [output][merged_folder], [output][merged_filename] 

```Bash
merge_tracks -c config.yaml
```



## Entry for replication data

Calculate the elevation and slope values for each datapoint from the OS terrain data
This will read the .csv file [merged_name] in [merged_folder] and add the following attributes
- a_OS height
- b_OS height
- OS height_diff
- a_OS slope
- b_OS slope

(a_ is the value at the start of the line segment, b_ is the value at the end)

```Bash
get_terrain -c config.yaml
```

### R data

The R file should be edited
All responses must be encl

type: osm or hikr
if type = osm, then hikr_filepath is required as the hikr data is used to filter the osm data to determine which are walking tracks

filepath = "/Volumes/LaCie/LaCie/LaCie Rugged USB-C/PackageDemo/OSM Out/Merged"
#input csv file
merged_file = "Merged.csv"
#If type = OSM, give full filepath of processed hikr data for filtering conditions
hikr_path = "/Volumes/LaCie/LaCie/LaCie Rugged USB-C/PackageDemo/Hikr Out/Merged/Merged.csv"

##OPTIONAL OUTPUTS
#File output with only useable breaks tagged (set to "" if not required)
valid_breaks_filename = ""#"UseableBreaks.csv"
#File output with data merged to 50m segments (set to "" if not required)
combined_50_filename = ""#"Merge50m.csv"
#File output with breaks tagged (set to "" if not required)
output_breaks = "DataPurgedBreaks.csv"

#File output with breaks removed (mandatory)
output = "DataPurged.csv"

The outputs of these can be merged together

e.g. rbind()




Check case sensitivity for terrain path

NOTE IT IS IMPORTANT TO CHANGE OUTPUT NAMES BETWEEN RUNS AS THEY WILL OVERWRITE PREVIOUS VERSIONS
ALSO OLD ONES ARENT DELETED, just overwritten so if a track has more segments it might stay

Copied & modified version of from https://github.com/SGroe/gpx-segment-importer

sys.path.append('/Users/Andrew/miniconda3/envs/QGIS/QGIS.app/Contents/Resources/python')
sys.path.append('/Users/Andrew/miniconda3/envs/QGIS/QGIS.app/Contents/Resources/python/plugins')