/* SAS curiosity cup 2025
Project name: Road Traffic Accidents in the US- 2022
Analysts: Urmi and Ojasvi
Advisor: Dr. William MacLeod
Data sets: 1. Kaggle road traffic accident data set
2. Popualtion data set*/

/* data dictionary:*/

/*Key data sets:
1. y022= accident dataset with year 2022 data only
2. dropped= accident data set with only the relevant variables from that data set
3. cup.filtered= accident data set- cleaned and ready for merging
4. cup.pop= population data set which was cleaned and ready for merging in a separate SAS program
5. cup.merged= merged data set ready for analysis
6. cup.rates= data set with state and country accident incidence rates
*/



/********Data set 1: Kaggle road traffic accident data**********/
/*Cleaning and preparing data set 1 for analysis*/
/* Setting up library */
libname cup "C:\Curoisity Cup";
/* Import accident data */
proc import file="C:\Curoisity Cup\US_Accidents_March23.csv"
out=cup.acc dbms=csv replace;
run;
proc contents data=cup.acc;
run;
title "Cup.acc unique state and zip";
proc sql;
    select count(distinct state) as unique_state, 
           count(distinct zipcode) as unique_zip
    from cup.acc;
quit;

proc print data=cup.acc (obs=20);
run;
/*To split the start time variable in to day, month, year and time for subsequent filtering of the year for analysis*/
data split;
set cup.acc;
dates= datepart(Start_Time); /* Extract the date part from Start_Time */
/* Extract month, year, and time */
month = MONTH(dates);
year = YEAR(dates);
time = TIMEPART(Start_Time);

/* Format the extracted date and time */
formatted_date = PUT(dates, DATE9.);  
formatted_time = PUT(time, TIME8.);

/* Extract day and month name */
date = DAY(dates);
month_name = PUT(dates, MONNAME3.); 
run;
proc contents data=split;
run;
proc print data= split (obs=50);
run;
/*creating new temporary dataset for just the year 2022*/
data y2022;
	set split;
	where year=2022;
run;
proc print data= y2022(obs=50);
run;
proc sql;
    select count(*) as n_obs from y2022;
quit;

/**Data Cleaning and ZIP Code Preparation**/
/* Keep only relevant variables and create standardized ZIP code format */
data zipped;
    set y2022;
    zip = substr(put(zipcode, 5.), 1, 5); /* Standardize ZIP to 5 digits */
    drop Source Start_Time End_Time Start_Lat Start_Lng End_Lat End_Lng 
         Street County Country Weather_Timestamp Civil_Twilight 
         Nautical_Twilight Astronomical_Twilight dates;
run;
proc print data=zipped (obs=10);
var zip;
run;
proc print data=zipped (obs=10);
    var _all_; 
run;
/*checking unique states and zips in the cleaned dataset zipped*/
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip
    from zipped;
run;
quit;

/*Saving the filtered data set which only consists of data from year 2022 with the variables of interest as permenant data set for further analysis*/
data cup.filtered;
	set zipped;
run;
/*proc contents data=cup.filtered;
run;
proc print data=cup.filtered(obs=50);
run;*/

/**Aggregating dataset based on zipcodes**/
/* Create simplified dataset with only location variables */
data simplified;
    set cup.filtered;
    keep State City ZIP;  /* Keep only location variables */
run;

/* Aggregate accidents by ZIP code */
proc sql;
    create table zip_counts_single as
    select zip,
           sum(accident_count) as accident_count
    from (select State, City, ZIP,
                 count(*) as accident_count
          from cup.filtered
          where zip ne ''
          group by State, City, ZIP)
    group by zip;
quit;
proc print data= zip_counts_single (obs=20);
run;
title "zipped unique state and zip";
proc sql;
    select
	count(distinct zip) as unique_zip
    from zipped;
run;
quit;

/***********Data set 2: Population Data set*********/
/*sorting the cleaned population data set saved as cup.pop by the variable zip (zipocode) to prepare for merging of the two data sets*/
proc sort data=zip_counts_single; by zip; run;

proc sort data=cup.pop;           by zip; run;
/*sorting the cleaned accident data set saved as zip_counts_single by the variable zip (zipocode) to prepare for merging of the two data sets*/
proc sort data=zip_counts_single; 
	by zip;
run;
/* Merge accident counts with population data */
data cup.merged;
   merge cup.pop(in=a) zip_counts_single(in=b);
   by zip;
   if a;   /* Keep only ZIPs that exist in population dataset */
run;
/*Checking if the merged data set has more variables and fewer observations compared to the filtered data set to verify if both data sets have merged based on the zipcodes in pop data set*/
/*proc contents data=cup.merged;
run;*/
/* No of variables and observation in the merged dataset has changed to  42 and 168009 respectively from 40 and 1762452 (filterted data set)*/
proc print data=cup.merged (obs=30);
run;

/*checking unique states and zips in the merged  dataset 
cleaned pop data set unique states  = 49, unique zipcodes= 18589
merged data set unique states= 37, unique zipcodes= 500 */
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip
    from cup.merged;
run;
quit;

/****************************************************************************/
/* Step 1: Calculate total accidents and population by state */
proc sql;
    create table state_totals as
    select distinct state_cleaned,
           sum(accident_count) as total_accidents_state,
           sum(population) as total_population_state
    from cup.merged
    group by state_cleaned;
quit;

/* Check state totals */
proc print data=state_totals;
    title "State-level Totals";
run;

/* Step 2: Calculate country totals */
proc sql;
    create table country_totals as
     select sum(total_accidents_state) as total_accidents_country,

           sum(total_population_state) as total_population_country
    from state_totals;
quit;

/* Check country totals */
proc print data=country_totals;
    title "Country-level Totals";
run;
/* Step 3: Create corrected state totals with proper state names */
proc sql;
    create table state_totals as
    select distinct 
        state_code,
        case state_code
            when 'DC' then 'DISTRICT OF COLUMBIA'
            when 'MA' then 'MASSACHUSETTS'
            when 'NC' then 'NORTH CAROLINA'
            when 'SC' then 'SOUTH CAROLINA'
            else state_cleaned
        end as state_cleaned,
        sum(accident_count) as total_accidents_state,
        sum(population) as total_population_state
    from cup.merged
    group by state_code, 
        calculated state_cleaned;
quit;
proc sort data=cup.merged;
    by state_code;
run;

proc sort data=state_totals;
    by state_code;
run;

/* Create final rates dataset */
data cup.rates;
    merge cup.merged(in=a) state_totals(in=b);
    by state_code;
    if a;
    if _n_ = 1 then set country_totals;  /* Fixed _n_ syntax */
    
    /* Calculate rates per 100,000 population */
    if population > 0 then 
        zip_incidence_rate = (accident_count / population) * 100000;
    if total_population_state > 0 then 
        state_incidence_rate = (total_accidents_state / total_population_state) * 100000;
    if total_population_country > 0 then 
        country_incidence_rate = (total_accidents_country / total_population_country) * 100000;

    /* Add formats */
    format population comma10.
           total_population_state comma12.
           total_population_country comma15.
           total_accidents_state comma8.
           total_accidents_country comma10.
           zip_incidence_rate 8.1
           state_incidence_rate 8.1
           country_incidence_rate 8.1;

    /* Add labels for clarity */
    label zip = "ZIP Code"
          population = "ZIP Code Population"
          accident_count = "Accidents in ZIP"
          total_accidents_state = "Total State Accidents"
          total_population_state = "State Population"
            total_accidents_country = "Total US Accidents"
          total_population_country = "US Population"
          zip_incidence_rate = "Accidents per 100K (ZIP)"
          state_incidence_rate = "Accidents per 100K (State)"
          country_incidence_rate = "Accidents per 100K (US)";
run;

title "cup.rates unique state, state codes and zips";
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct state_code) as unique_state_code,
	count(distinct zip) as unique_zip
    from cup.rates;
run;
quit;

/* Final verification of unique ZIP codes */
proc sql;
    select count(*) as total_records,
           count(distinct zip) as unique_zips,
           case when calculated total_records = calculated unique_zips 
                then 'No duplicates'
                else 'Duplicates exist'
           end as check_result
    from cup.rates;
quit;
/* View results */
proc print data=cup.rates (obs=20)label;
run;

title "cup.rates unique state, state codes and zips after final verification";
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct state_code) as unique_state_code,
	count(distinct zip) as unique_zip
    from cup.rates;
run;
quit;

/* End of this SAS Program*/
/* Next analysis file analysis_WIP*/
