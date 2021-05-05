This repo provides the methods required to recreate the dataset of walking and hiking tracks in the walking speeds paper.

- Preparation
    - OS Terrain 5 DTM
    - Conda Environment
    - Config file
- Replication
    - GPS tracks
    - Import files
    - Tag breakpoints
    - Merge files
    - Terrain Calculation
    - Filter and Merge Tracks
    
 For replication of the methods used in the paper, the full guide should be followed, 
however to simply recreate the dataset of filtered walking tracks you should jump 
straight to the Terrain Calculation using the Hikr.csv and OSM.csv files as inputs,
after the Preparation section
 
Note: If replicating the methods in full, be aware that the ```find_breaks``` script takes a very long time to run. 
(~1 week on 2018 MacBook Air, 1.6 GHz Dual-Core Intel Core i5, 8 GB 2133 MHz LPDDR3)


##Preparation

#### OS Terrain 5 DTM

Due to licensing requirements, the Digital Terrain Map containing elevation data required for calculating both walking and hill slope angles 
is not available for public download and must be accessed separately. It is available under an Educational License from Digimap and should be 
accessed using the [Bulk Download Request form](https://goo.gl/FxyyFs),
with the following criteria:

Data Collection : Digimap: Ordnance Survey  
Dataset : OS Terrain 5 DTM  
Area : Scotland coverage  
Format : ASC

This should result in receiving data for the region covered by the following 100 km National Grid tiles:

                HP
             HT HU
       HW HX HY HZ
    NA NB NC ND   
    NF NG NH NJ NK
    NL NM NN NO
       NR NS NT NU
       NW NX NY 

Note: the NY tile may not contain all constituent 5km tiles, as the majority of the NY region covers England. 
The following NY tiles are sufficient to include all data for Scotland, however having more files will not cause issues.

    09 19 29 39 49 59 69
    08 18 28 38 48 58 
    07 17 27 37 47 
    06 16 26 36 
        
#### Conda Environment

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

#### Config file

The file config.yaml contained within this package is used as the configuration file
for reading and importing the data, and should be edited to point to the correct file locations.
The scripts which each variable is used in are shown below. 

- **qgis_path** : The path of the qgis executable within the conda environment  
On MacOS: [environment_path]/QGIS.app/Contents/MacOS
- **filetype** : should be set to either *osm* or *hikr* depending on which data type is being read 
- **data**
  - **os_grid_folder** : Folder containing OS National grid files 
    ```
    .
    ├── os-grids
        └── 10km_grid_region.shp
        └── 100km_grid_region.shp
         ⋮
    ```
  - **GPS_files**
    - **hikr**
      - **website** : address of Hikr results to parse for GPS data  
      - **folder** : Location of json file containing hikr data links
      - **name** : Filename of json file containing hikr data links
    - **osm**
      - **folder** : Location of OpenStreetMap tracks to be read
  - **terrain**
    - **DTM_folder** : Top level folder containing DTM files e.g 
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
    - **DTM_resolution** : Resolution of DTM data (should be set to 5)  
  - **processed_hikr_filepath** : If type = osm, give filepath of processed hikr data to use for filtering in ```PrepareData.R``` script

- **conditions**
  - **data_filter** : Whether to run initial filter on OSM data to remove files which are not in scope (not required but speeds up processing), should be set to False if already filtered dataset
  - **in_scope_folder** : location to copy in-scope .gpx files 
- **output** 
  - **gpkg_folder** : Location to save gpkg output files 
  - **name_root** : Name stem for gpkg files, indexes are automatically added for each new track & segment, e.g Data0_001 
  - **merged_folder** : location to save merged .gpkg and .csv files 
  - **merged_name** : file name to save merged .gpkg and .csv files
  - **processed_folder** : destination folder for processed & filtered output files
  - **optional**
    - **valid_breaks_filename** : filename for dataset with only valid breaks (>30 seconds) tagged
    - **combined_50_filename** : filename for dataset with data combined into 50m segments 
    - **processed_breaks_filename** : filename for processed & filtered dataset with breaks tagged
  - **processed_filename** : filename for processed & filtered dataset with breaks/non-walking sections removed

## Replication

#### GPS tracks:

The list of Hikr tracks used can be found in Hikr_filepaths.json. 
Note that this file can be reproduced by running the ```scrape``` script with 
website = https://www.hikr.org/region518/ped/?gps=1 in the config file

```Bash
scrape -c config.yaml
```

The OSM tracks used are saved in the scotland.tar.xz file which should be unzipped. This is a duplicate of the planet.osm
gpx file list for scotland which is available [here](http://zverik.openstreetmap.ru/gps/files/extracts/europe/great_britain)
Alternatively, the OSM_Inscope folder can be used; this contains only the GPS tracks which are not filtered out during the process

#### Importing Files:

The code to import the files is a modified version of the gpx_segment_importer
QGIS plugin: https://github.com/SGroe/gpx-segment-importer

The ```run_gpx_importer``` script will the .json file ([filetype] = hikr), or folder ([filetype] = osm), and import gpx files as .gpkg files.
These files are saved to the config [output][gpkg_folder].

If running with osm data and filter = True, this will also save all of the valid gpx files to in_scope_folder, which can be used as
the input location in future for faster processing.

```Bash
run_gpx_importer -c config.yaml
```

It is important to change the output file location or name between runs, as previous tracks will be overwritten.
It is recommended that separate output folder are used for hikr and osm data, as they will need to be in separate folders
at the Merge Files stage.

#### Tagging Breakpoints:

The ```find_breaks``` script will add an 'OnBreak' attribute to each gpkg file, using the methods outlined in the paper.  
This script will also delete files which are clearly not walking tracks (median speed > 10km/h), 
or don't contain enough data to be useful (distance < 250m or duration < 2.5 minutes)

```Bash
find_breaks -c config.yaml
```

#### Merge files:

The ```merge``` script takes all of the files in [output][gpkg_folder] 
and combines them into a single file, [output][merged_filename], saved in [output][merged_folder].  
It is important to merge hikr and OSM files separately, as the merged hikr tracks are used to filter non-walking tracks out 
of the OSM dataset later on.

```Bash
merge_tracks -c config.yaml
```

#### Terrain Calculation

The ```get_terrain``` script will calculate the elevation and slope values for each line segment from the OS terrain data.  
It reads the [merged_name] .csv file in [merged_folder] and adds the following attributes:
- a_OS height
- b_OS height
- OS height_diff
- a_OS slope
- b_OS slope  

(a_ is the value at the start of the line segment, b_ is the value at the end)

```Bash
get_terrain -c config.yaml
```

### Data combination & filtering

The ```PrepareData.R``` script reads the ```[merged_filename]``` .csv and 
filters / combines the data for use in modelling. 
This script must first be run with ```[filetype] = hikr```. The ```[processed_filename]``` output of this 
should then be set as the the ```[processed_hikr_filepath]```  input when running with ```[filetype] = osm```, so that 
the OSM data can be filtered to remove any non-walking tracks or segments.

```bash
Rscript PrepareData.R config.yaml
```

The outputs of these can be merged together

```R
> combined_dataset = rbind(hikr_output, osm_output)
```

This combined dataset can then be used to model walking speeds
