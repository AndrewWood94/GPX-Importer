#Calculate walking slope values & set NA to zero
walkingSlope = function(df){
  #Calculate walking slope values
  df["slopeOS"] = atan(df$OS.height_diff/df$distance)*180/pi
  df["slope"] = atan(df$elevation_diff/df$distance)*180/pi
  #Set all null values to zero
  df[is.na(df)]=0
  df = select(df, -OnBreak, everything())
  return(df)
}
# if getlengths = true, find lengths of all breaks in dataframe
# if getlengths = false, tag all breaks > minbreak or containing speed > speedcutoff with OnBreak = 2
findbreaks = function(df, getlengths, minbreak=NULL, speedcutoff = Inf){
  segnos = unique(df$Segment.No)  #Get Segment Numbers
  breaklengths=vector()
  for (segment in segnos) {
    print(segment)
    Onbreak=FALSE
    HighSpeedBreak = FALSE
    duration = 0
    points = df[df$Segment.No == segment, ] 
    for (i in 1:nrow(points)){    #For each segment, loop over the points
      #If breakpoint
      if ((points[ i, 'OnBreak'] == 1) | (points[ i, 'OnBreak'] == 2)) {
        if(duration==0){          #If point is first breakpoint, note start 
          Onbreak = TRUE
          BreakStart=i
        }
        #If break is at start of segment, or contains a high speed point, tag it
        if(i ==1 | points [i, 'speed'] >= speedcutoff){
          HighSpeedBreak = TRUE
        }
        duration = duration + points [i, 'duration']  #Calculate break duration
      }
      
      else {
        #If previously on break
        if(Onbreak) {
          breaklengths = c(breaklengths, duration)  #Save length of previous break
          Onbreak = FALSE
          if (!getlengths){                         #If not finding breaklengths
            if (duration >= minbreak | HighSpeedBreak == TRUE) {   #Tag all breaks above minimum length
              for (j in BreakStart:(i-1)) {
                df[df$fid == points[j, 'fid'], 'OnBreak'] = 2
              }
            }
          }
          duration = 0
          HighSpeedBreak = FALSE
        }
      }
    }
    #If final points in segment are a break, classify them anyway
    if(Onbreak){
      breaklengths = c(breaklengths, duration)
      Onbreak = FALSE
      if (!getlengths){
        for (j in BreakStart:i) {
          df[df$fid == points[j, 'fid'], 'OnBreak'] = 2
        }
      }
    }
  }
  #If getting lengths return vector of breaklengths
  if (getlengths){
    return(breaklengths)
  }
  #Otherwise return dataframe with tagged long breaks
  else{
    return(df)
  }
}
# merge data into intervals, split on variable [type], minimum interval size [condition]
datamerge=function(df,type, condition, terrain = list()){
  
  nameslist=c("WKT", "fid", "Segment.No", "Start_DateTime", "duration", "distance", "speed", 
              "elev_diff_gps", "elev_gain_gps", "elev_drop_gps", 
              "elev_diff_OS", "elev_gain_OS", "elev_drop_OS", 
              "avg_ground_slope_a", "avg_ground_slope_b", "slopeOS", "slope", "OnBreak", terrain)
  merged = setNames(data.frame(matrix(ncol = length(nameslist), nrow = 0)), nameslist)
  
  segnos = unique(df$Segment.No)
  
  variables = list('wkt'='', 'fid'=1, 'segno'=0, 
                   'dateTime'='','duration'=0,'distance'=0,
                   'elev_diff_gps'=0,'elev_gain_gps'=0,'elev_drop_gps'=0,
                   'elev_diff_OS'=0,'elev_gain_OS'=0,'elev_drop_OS'=0,
                   "avg_ground_slope_a"=0, "avg_ground_slope_b"=0, 
                   "avg_slopeOS"=0, "avg_slope"=0,
                   'OnBreak'= 0)
  for (segno in segnos) {
    print(segno)
    
    sample = df[df$Segment.No==segno,]
    variables$segno = segno
    variables$dateTime=sample[1,]$a_time
    
    start_point = strsplit(strsplit(sample[1,]$WKT, ',')[[1]][1],'\\(')[[1]][2]
    variables$wkt = paste("LINESTRING (" , start_point, sep='')
    
    for (i in 1:nrow(sample)){
      #If next point is part of a long break, save the previous point to output
      if(sample[i, 'OnBreak']==2){
        
        if (!variables$OnBreak){
          
          start_point = strsplit(strsplit(sample[i,]$WKT, ',')[[1]][1],'\\(')[[1]][2]
          variables$wkt = paste(variables$wkt, start_point, sep=',')
          variables$wkt = paste(variables$wkt, ')', sep='')
          
          added = savePoint(merged, variables)
          merged = added[[1]]
          variables = added[[2]]
          variables$dateTime=sample[i,]$a_time
          variables$OnBreak = 1
          variables$wkt = paste("LINESTRING (" , start_point, sep='')
        }
        variables$duration = variables$duration + sample[i,]$duration
        variables$distance = variables$distance + sample[i,]$distance
      }
      
      else{
        #If end of break, or timethreshold met, save break or previous section
        if (variables$OnBreak | variables[[type]]>condition){
          start_point = strsplit(strsplit(sample[i,]$WKT, ',')[[1]][1],'\\(')[[1]][2]
          variables$wkt = paste(variables$wkt, start_point, sep=',')
          variables$wkt = paste(variables$wkt, ')', sep='')
          
          added = savePoint(merged, variables)
          merged = added[[1]]
          variables = added[[2]]
          variables$dateTime=sample[i,]$a_time
          variables$wkt = paste("LINESTRING (" , start_point, sep='')
        }
        
        variables$duration = variables$duration + sample[i,]$duration
        variables$distance = variables$distance + sample[i,]$distance
        
        variables$elev_diff_gps = variables$elev_diff_gps + sample[i,]$elevation_diff
        if (sample[i,]$elevation_diff > 0) {
          variables$elev_gain_gps = variables$elev_gain_gps + sample[i,]$elevation_diff
        }
        else {
          variables$elev_drop_gps = variables$elev_drop_gps + sample[i,]$elevation_diff
        }
        
        variables$elev_diff_OS = variables$elev_diff_OS + sample[i,]$OS.height_diff
        if (sample[i,]$OS.height_diff > 0) {
          variables$elev_gain_OS = variables$elev_gain_OS + sample[i,]$OS.height_diff
        }
        else {
          variables$elev_drop_OS = variables$elev_drop_OS + sample[i,]$OS.height_diff
        }
        
        #Calculate slopes as weighted average of time spent on slope 
        variables$avg_ground_slope_a = variables$avg_ground_slope_a + (sample[i,]$a_OS.slope*sample[i,]$duration)
        variables$avg_ground_slope_b = variables$avg_ground_slope_b + (sample[i,]$b_OS.slope*sample[i,]$duration)
        
        if (sample[i,]$distance>0){
          variables$avg_slopeOS = variables$avg_slopeOS + atan(sample[i,]$OS.height_diff/sample[i,]$distance)*180/pi*sample[i,]$duration
          variables$avg_slope = variables$avg_slope + atan(sample[i,]$elevation_diff/sample[i,]$distance)*180/pi*sample[i,]$duration
        }
        
        for (item in terrain) {
          if (sample[[item]][i]==1) {
            merged[variables$fid,][[item]]=1
          }
        }
        
      }
    }
    end_point = strsplit(sample[i,]$WKT, ',')[[1]][2]
    variables$wkt = paste(variables$wkt, end_point, sep=',')
    
    added = savePoint(merged, variables)
    merged = added[[1]]
    variables = added[[2]]
  }
  merged$speed=(merged$distance/1000)/(merged$duration/3600)
  merged[is.na(merged)]=0
  return(merged)
}
savePoint = function(df, variables){
  if(variables$duration >0){
    k = variables$fid
    df[k,]$WKT = variables$wkt
    df[k,]$fid = k
    df[k,]$Segment.No = variables$segno
    df[k,]$Start_DateTime = variables$dateTime
    df[k,]$duration = variables$duration
    df[k,]$distance = variables$distance
    df[k,]$elev_diff_gps = variables$elev_diff_gps 
    df[k,]$elev_gain_gps = variables$elev_gain_gps
    df[k,]$elev_drop_gps = variables$elev_drop_gps
    df[k,]$elev_diff_OS = variables$elev_diff_OS
    df[k,]$elev_gain_OS = variables$elev_gain_OS
    df[k,]$elev_drop_OS = variables$elev_drop_OS
    df[k,]$avg_ground_slope_a = variables$avg_ground_slope_a / variables$duration
    df[k,]$avg_ground_slope_b = variables$avg_ground_slope_b  / variables$duration
    df[k,]$slopeOS = variables$avg_slopeOS/variables$duration
    df[k,]$slope = variables$avg_slope/variables$duration 
    df[k,]$OnBreak = variables$OnBreak
    
    variables = list('wkt'= '', 'fid'=k+1, 'segno'=variables$segno, 
                     'dateTime'='','duration'=0,'distance'=0,
                     'elev_diff_gps'=0,'elev_gain_gps'=0,'elev_drop_gps'=0,
                     'elev_diff_OS'=0,'elev_gain_OS'=0,'elev_drop_OS'=0,
                     "avg_ground_slope_a"=0, "avg_ground_slope_b"=0, 
                     "avg_slopeOS"=0, "avg_slope"=0,
                     'OnBreak'= 0)
  }
  return (list(df, variables))
}
#Filter data using known walking data as criteria
DataRemoval = function(df, known_values){

  ##  DEAL WITH SEGMENTS WITH WALK/DRIVE SPLIT BY EXTREME POINTS ##
  
  for (i in sort(unique(df$Segment.No))){
    fids = c(min(df$fid[df$Segment.No == i]), max(df$fid[df$Segment.No == i]))  
    fids = c(fids, df$fid[df$Segment.No==i & (df$distance>500 | df$duration>600 | df$speed>100)])
    fids = sort(unique(fids))
    
    #Segments with extreme speeds
    if(length(fids)>2){
      for (j in (1:(length(fids)-1))){
        #Segments with only one valid point in interval have point set to be a break
        if (length(df$speed[df$fid>=fids[j] & df$fid<=fids[j+1] & df$OnBreak == 0])==1){
          df$OnBreak[df$fid>=fids[j] & df$fid<=fids[j+1] & df$OnBreak == 0]=1
        }
        else if (length(df$speed[df$fid>=fids[j] & df$fid<=fids[j+1] & df$OnBreak == 0])>1){
          quant=quantile(df$speed[df$fid>=fids[j] & df$fid<=fids[j+1] & df$OnBreak == 0])
          #If median speed > upper quartile of known maximum speed, set segment section to be a break
          if (quant[[3]] > known_values$Q3max){
            df$OnBreak[df$fid>=fids[j] & df$fid<=fids[j+1]]=1
          }
        }
      }
    }
  }
  
  #Remove Segments where there is less than 2.5min or 250m of useable data
  segment_ignore=vector()
  for(i in sort(unique(df$Segment.No))){
    if ((sum(df$duration[df$Segment.No==i & df$OnBreak==0])<=150) | (sum(df$distance[df$Segment.No==i & df$OnBreak==0])<=250)) {
      segment_ignore =c(segment_ignore, i)
    }
  }
  df = subset(df, !(df$Segment.No %in% segment_ignore))

  #If median speed > upper quartile of known maximum speed
  #minimum speed > median of known medians
  #upper quartile > whiskers of known max, ignore
  #top whisker < minimum of known upper quartiles, ignore
  to_remove = vector()
  for(i in sort(unique(df$Segment.No))){
    quant=quantile(df$speed[df$Segment.No==i & df$OnBreak==0])
    top_whisker = boxplot(df$speed[df$Segment.No==i & df$OnBreak==0], plot=FALSE)$stats[5]
    if (quant[3] > known_values$Q3max){
      to_remove = c(to_remove, i)
    }  
    else if (quant[1] > known_values$medmed){
      to_remove = c(to_remove, i)
    }
    else if (quant[4] > known_values$whiskermax){
      to_remove = c(to_remove, i)
    }
    if (top_whisker < known_values$minQ3){
      to_remove = c(to_remove, i)
    }
  }
  df = subset(df, !(df$Segment.No %in% to_remove))

  return(df)
}
#Find points adjacent to break points, gaps, or start/end of segment where speed > highspeed and mark as break
highspeedcheck = function(df, highspeed){
  fast = df$fid[df$speed>highspeed & df$OnBreak==0]
  for (i in fast){
    #If previous/next point in segment is a break point
    if (any(df$OnBreak[(df$Segment.No == df$Segment.No[df$fid == i]) & (df$fid == (i+1) | df$fid == (i-1))]==1) |
        #If previous/next point doesnt exist (end of segment or gap in data)
        length(df$Segment.No[(df$fid == (i+1) | df$fid == (i-1))]) < 2 |
        #If previous/next point is in a different segment(end of segment)
        any(df$Segment.No[(df$fid == (i+1) | df$fid == (i-1))] != df$Segment.No[df$fid == i])){
      df$OnBreak[df$fid == i] = 1
    }
  }
  return(df)
}
#if getlengths = true, return lengths of all sections between breaks (mini-segments)
#If getlengths = False, tag all mini-segments where the distance < mindist as breaks
finddists = function(df, getlengths, mindist=NULL){
  distances = vector()
  for (i in sort(unique(df$Segment.No))){
    distance = 0
    points = df[df$Segment.No == i, c('distance', 'OnBreak', 'fid')] 
    for (i in 1:nrow(points)){    #For each segment, loop over the points
      if (points[ i, 'OnBreak'] == 0){
        if (distance == 0){
          section_start = i
        }
        distance = distance + points[i , 'distance']
      }
      else if (distance > 0){
        distances = c(distances, distance)
        if (!getlengths){
          if (distance <= mindist) {
            for (j in section_start:i) {
              df[df$fid == points[j, 'fid'], 'OnBreak'] = 1
            }
          }
        }
        distance  = 0
      }
    }
    if (distance > 0){
      distances = c(distances, distance)
      if (!getlengths){
        if (distance <= mindist) {
          for (j in section_start:i) {
            df[df$fid == points[j, 'fid'], 'OnBreak'] = 1
          }
        }
      }
    }
  }
  if (getlengths){
    return(distances)
  }
  #Otherwise return dataframe with tagged long breaks
  else{
    return(df)
  }
}

prepare = function(parameters){
  
  type = tolower(parameters$input$type)
  out_folder = parameters$output$folder
  
  if (is.null(out_folder)){
    print("output folder not specified")
    return("error")
  }
  else if (!dir.exists(out_folder)){
    dir.create(out_folder)
    print(c("folder created: ", out_folder))
  }
  

  if (type != "hikr"){
      if (is.null(parameters$input$hikr_filepath)){
        print("missing known dataset path for filter")
        return("error")
      }

      hikrdata = read.csv(parameters$input$hikr_filepath, header = TRUE, sep = ",", stringsAsFactors = FALSE)
      
      known_max_speed = vector()
      known_median_speed = vector()
      known_q3_speed = vector()
      
      for(i in sort(unique(hikrdata$Segment.No))){
        quants=quantile(hikrdata$speed[hikrdata$Segment.No==i])
        known_max_speed = c(known_max_speed, quants[[5]])
        known_q3_speed = c(known_q3_speed, quants[[4]])
        known_median_speed = c(known_median_speed, quants[[3]])
      }
      
      HikrValues = list(Q3max = quantile(known_max_speed, 0.75)[[1]],
                        whiskermax = boxplot(known_max_speed, plot=FALSE)$stats[5],
                        medmed = median(known_median_speed),
                        minQ3 = min(known_q3_speed))
      #HikrValues = list(Q3max = 5.869302,whiskermax = 7.490433,medmed = 3.02698,minQ3 = 2.448512)
  }
  
  AllData = read.csv(paste0(parameters$input$merged_filepath), header = TRUE, sep = ",", stringsAsFactors = FALSE)
  
  #Calculate walking slope values & set zero movement points to breaks
  
  AllData=walkingSlope(AllData)
  AllData$OnBreak[AllData$distance==0]=1
  
  #Tag any points with over 1km travel or 600m distance as a fixed break
  AllData$OnBreak[AllData$distance>=1000]=2
  AllData$OnBreak[AllData$duration>=600]=2
  
  ##Get lengths of breaks in the data
  #breaklengths = findbreaks(AllData, getlengths = TRUE)
  
  #Tag all breaks longer than minimum threshold
  AllData = findbreaks(AllData, getlengths = FALSE, minbreak = 30, speedcutoff = 10)
  #Save as new file
  if (!is.null(parameters$output$optional$valid_breaks_filename)){
    write.csv(AllData,paste0(out_folder,'/',parameters$output$optional$valid_breaks_filename,'.csv'), row.names = FALSE)
  }
  #Merge data into 50m intervals
  AllData50m = datamerge(AllData, 'distance', 50)
  #Ignore points under 50m
  AllData50m$OnBreak[AllData50m$distance <= 50] = 1
  
  #Save as new file
  if (!is.null(parameters$output$optional$combined_50_filename)){
    write.csv(AllData50m,paste0(out_folder,'/',parameters$output$optional$combined_50_filename,'.csv'), row.names = FALSE)
  }
  
  if (type=="hikr"){
    #Remove segments with mean speed above 10km/h
    removals=vector()
    for(i in unique(AllData50m$Segment.No)){
      mean_speed = mean(AllData50m$speed[AllData50m$Segment.No==i & AllData50m$OnBreak==0])
      if (is.na(mean_speed) | mean_speed > 10){
        removals=c(removals, i)
      }
    }
    AllData50m = subset(AllData50m, !(AllData50m$Segment.No %in% removals))

    #Remove sections with less than 250m between breaks
    AllData50m = finddists(AllData50m, getlengths = FALSE, mindist = 250)
    AllData50mNoBreaks=subset(AllData50m, AllData50m$OnBreak==0)
  }
  else if (type=="osm"){
    #Filter dataset to remove tracks which don't match known walking profile
    AllData50m = DataRemoval(AllData50m, HikrValues)
    AllData50mNoBreaks = subset(AllData50m, AllData50m$OnBreak==0)
    
    #Loop to remove high speed / short points
    current_length = Inf
    while (length(AllData50mNoBreaks[,1])<current_length){
      current_length=length(AllData50mNoBreaks[,1])
      AllData50m = finddists(AllData50m, getlengths = FALSE, mindist = 250)
      AllData50m = highspeedcheck(AllData50m, highspeed = 10)
      AllData50m = DataRemoval(AllData50m, HikrValues)
      AllData50mNoBreaks = subset(AllData50m, AllData50m$OnBreak==0)
    }
  }
  

  if (!is.null(parameters$output$optional$output_breaks_filename)){
    write.csv(AllData50m,paste0(out_folder,'/',parameters$output$optional$output_breaks_filename,'.csv'), row.names = FALSE)
  }
  write.csv(AllData50mNoBreaks,paste0(out_folder,'/',parameters$output$output_filename,'.csv'), row.names = FALSE)
  return(AllData50mNoBreaks)
}

