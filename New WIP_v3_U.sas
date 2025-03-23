/* SAS curiosity cup 2025
Project name: Road Traffic Accidents in the US- 2022
Analysts: Urmi and Ojasvi
Advisor: Dr. William MacLeod
Data sets: cup.rates created through 'WIP_v1_U.sas' codes */

libname cup"C:\Curoisity Cup";
data work.rates;
set cup.rates;
run;
proc print data=work.rates (obs=20);
run;
proc freq data=work.rates;
tables state_code;
run;
title "verifying cup.rates unique state and zips before analysis";
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip
    from  cup.rates;
run;
quit;

/* Creating regions****/
data regions;
    set work.rates;
    
    if state_code in ("CT", "ME", "MA", "NH", "NJ", "NY", "PA", "RI", "VT") then region = "Northeast";
    else if state_code in ("IL", "IN", "IA", "KS", "MI", "MN", "MO", "NE", "ND", "OH", "SD", "WI") then region = "Midwest";
    else if state_code in ("AL", "AR", "DE", "DC", "FL", "GA", "KY", "LA", "MD", "MS", "NC", "OK", "SC", "TN", "TX", "VA", "WV") then region = "South";
    else if state_code in ("AK", "AZ", "CA", "CO", "HI", "ID", "MT", "NV", "NM", "OR", "UT", "WA", "WY") then region = "West";
    else if state_code = "PR" then region = "Territory";
else region = "Other";
run;
title "Verifying unique state and zips in regions data set";
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip,
	count(distinct region) as unique_regions
    from regions;
run;
quit;

proc freq data=regions;
    tables state_code*region / list;
run;
proc sort data=regions out=unique_states;
    by state_code;
run;
proc print data=regions(obs=30);
run;
/*checking unique states and regions in the 
previous cleaned data set cup.merged: unique_state= 37 unique_zip= 500
current data set unique_states: unique_state= 37 unique_zip= 37 unique_regions= 5
*/
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip,
	count(distinct region) as unique_regions
    from unique_states;
run;
quit;
proc sort data=regions out=unique_states;
    by state_code;
run;
proc freq data=unique_states;
    tables region / nocum;
run;

/*checking unique states and regions in the 
previous cleaned data set cup.merged: unique_state= 37 unique_zip= 500
current data set unique_states: unique_state= 37 unique_zip= 37 unique_regions= 5
*/
proc sql;
    select
	count(distinct state) as unique_state,
	count(distinct zip) as unique_zip,
	count(distinct region) as unique_regions
    from unique_states;
run;
quit;

/*Map for state incidence rates*/

proc contents data=maps.us;
run;


data ratescoding;
    set cup.rates;
    rename state_code = statecode;
run;
/* Setting a blue gradient pattern for heat map */
pattern1 v=solid color=CXE8E8FF; /* Lightest blue */
pattern2 v=solid color=CXBFBFFF;
pattern3 v=solid color=CX9696FF;
pattern4 v=solid color=CX6D6DFF;
pattern5 v=solid color=CX4444FF;
pattern6 v=solid color=CX1B1BFF; /* Darkest blue */

/* State-level incidence rate heat map */
proc gmap data=ratescoding map=maps.us;
    id statecode;
    choro state_incidence_rate / 
        levels=6 
        coutline=gray
        legend=legend1;
    title1 "State-Level Accident Incidence Rates per 100,000 Population";
    title2 "(2022)";
    format state_incidence_rate 8.1;
run;
quit;
	/* Regional map - using distinct colors for regions */
data regionsmap;
    set regions;
    rename state_code = statecode;
run;

/* Distinct colors for regions */
pattern1 v=solid color=CX4169E1; /* Royal Blue for Northeast */
pattern2 v=solid color=CX228B22; /* Forest Green for Midwest */
pattern3 v=solid color=CXB8860B; /* Dark Golden Rod for South */
pattern4 v=solid color=CX8B4513; /* Saddle Brown for West */
pattern5 v=solid color=CX4B0082; /* Indigo for Territory */
pattern6 v=solid color=CX708090; /* Slate Gray for Other */

proc gmap data=regionsmap map=maps.us;
    id statecode;
    choro region / 
        discrete
        coutline=gray
        legend=legend1;
    title1 "U.S. Regions Classification";
    title2 "Road Traffic Accident Analysis (2022)";
run;
quit;

/* Region-wise average incidence rates heat map */
proc sql;
    create table region_rates as
    select region, 
           mean(state_incidence_rate) as avg_incidence_rate
    from regionsmap
    group by region;
quit;

proc sql;
    create table regionsmap_final as
    select a.*, b.avg_incidence_rate
    from regionsmap a
    left join region_rates b
    on a.region = b.region;
quit;

/* Reset patterns for the regional heat map */
pattern1 v=solid color=CXE8E8FF; /* Lightest blue */
pattern2 v=solid color=CXBFBFFF;
pattern3 v=solid color=CX9696FF;
pattern4 v=solid color=CX6D6DFF;
pattern5 v=solid color=CX4444FF;
pattern6 v=solid color=CX1B1BFF; /* Darkest blue */

proc gmap data=regionsmap_final map=maps.us;
    id statecode;
    choro avg_incidence_rate / 
        levels=6
        coutline=gray
        legend=legend1;
    title1 "Regional Average Accident Incidence Rates";
    title2 "per 100,000 Population (2022)";
    format avg_incidence_rate 8.1;
run;
quit;
/************More exploratory analysis******/
/* 5 Regions Bar Graph */
/* Sort the data by region */
proc sort data=regions out=region_counts;
    by region;
run;

/* Count the frequency of each region */
proc freq data=region_counts noprint;
    tables region / out=region_freq;
run;

/* Create a bar chart for regions */
title "Distribution of Road Traffic Accidents by Region (2022)";
proc sgplot data=region_freq;
    vbar region / response=count fillattrs=(color=blue) 
                  datalabel datalabelattrs=(size=10) 
                  categoryorder=respdesc;
    xaxis label="Region";
    yaxis label="Number of ZIP Codes";
    format count comma8.;
run;

/* Regional Incidence Rate Analysis */
proc sql;
    create table region_incidence as
    select region, 
           mean(zip_incidence_rate) as avg_incidence_rate
    from regions
    group by region;
quit;

/* Create bar chart of regional incidence rates */
title "Average Accident Incidence Rates by Region (per 100,000 Population)";
proc sgplot data=region_incidence;
    vbar region / response=avg_incidence_rate fillattrs=(color=blue) 
                  datalabel datalabelattrs=(size=10);
    xaxis label="Region";
    yaxis label="Average Incidence Rate per 100,000";
run;

/* Top 10 States by Incidence Rate */
/* Create a state-level summary with unique state incidence rates */
proc sql;
   create table state_summary as
   select distinct state_code, 
                  state_cleaned,
                  state_incidence_rate,
                  total_accidents_state, 
                  total_population_state
   from cup.rates
   order by state_incidence_rate desc;
quit;

/* Print the state summary to verify data */
proc print data=state_summary(obs=20);
   title "State-Level Incidence Rates";
   var state_code state_cleaned state_incidence_rate total_accidents_state total_population_state;
run;

/* Extract top 10 states by incidence rate */
data top10_by_incidence;
   set state_summary;
   if _n_ <= 10;  /* Keep only first 10 records after sorting */
run;

/* Visualize top 10 states by incidence rate */
proc sgplot data=top10_by_incidence;
   hbar state_code / response=state_incidence_rate 
       categoryorder=respasc    /* Ascending order on chart */
       datalabel datalabelattrs=(size=10)
       fillattrs=(color=blue);
   xaxis label="Incidence Rate per 100,000 Population" grid;
   yaxis label="State Code" grid;
   title "Top 10 States by Accident Incidence Rate (per 100,000 Population)";
   format state_incidence_rate comma8.1;
run;




/******************************/
	/* Create a working copy that includes the log of population for offset */
data analysis;
    set regions;
    /* Example using zip-level population as the offset. 
       If you have a state-level population, use that instead. */
    log_pop = log(population);
run;
	proc genmod data=analysis;
    class region (ref="Northeast") / param=ref;
    model accident_count = region
        / dist=poisson 
          link=log 
          offset=log_pop
          type3
          scale=pearson;
    title "Poisson Model - Region-wise Analysis (ZIP-level Accidents)";
run;
proc genmod data=analysis;
    class region (ref="Northeast") / param=ref;
    model accident_count = region
        / dist=negbin
          link=log
          offset=log_pop
          type3
          waldci;       /* Wald confidence intervals */
    title "Negative Binomial Model - Region-wise Analysis (No Additional Covariates)";
run;


proc genmod data=analysis;
    class state_code (ref="NY") / param=ref;
    model accident_count = state_code
        / dist=negbin
          link=log 
          offset=log_pop
          type3
          waldci;
    title "Negative Binomial Model - State-wise Analysis (No Additional Covariates)";
run;

/* Create dataset with region coefficients from the negative binomial model */
data region_coeffs;
    length region $10;
    input region $ estimate pValue;
    /* Convert log coefficients to incidence rate ratios */
    irr = exp(estimate);
    /* Calculate percentage difference from reference */
    pct_diff = (irr - 1) * 100;
    datalines;
Northeast 0      1.0000
Midwest   -0.8054 0.0004
South     0.4128  0.0102
Territory 0      1.0000
West      0.5378  0.0010
;
run;

/* Create a bar chart of region incidence rate ratios */
title "Regional Incidence Rate Ratios (Compared to Northeast)";
footnote "Based on Negative Binomial Regression Model";
proc sgplot data=region_coeffs;
    vbar region / response=irr fillattrs=(color=blue) 
                 datalabel datalabelattrs=(size=10);
    refline 1 / axis=y lineattrs=(pattern=dash);
    xaxis label="Region";
    yaxis label="Incidence Rate Ratio (IRR)" min=0;
    format irr 4.2;
run;

/* Create dataset with significant state coefficients from the negative binomial model */
data state_coeffs;
    length state_code $2;
    input state_code $ estimate pValue significant;
    /* Convert log coefficients to incidence rate ratios */
    irr = exp(estimate);
    /* Calculate percentage difference from reference */
    pct_diff = (irr - 1) * 100;
    datalines;
NY 0       1.0000 0
FL 1.1941  0.0001 1
CA 0.7206  0.0001 1
VA 1.0269  0.0018 1
NC 0.9745  0.0031 1
IL -1.0431 0.0001 1
KY -3.5021 0.0001 1
CO -1.0456 0.0200 1
NM -1.7626 0.0049 1
OH -0.9804 0.0088 1
OK -1.6395 0.0087 1
WA -1.5307 0.0018 1
;
run;

/* Sort the state coefficients by IRR */
proc sort data=state_coeffs;
    by descending irr;
run;

/* Create a bar chart of state incidence rate ratios */
title "State Incidence Rate Ratios (Compared to New York)";
title2 "Only States with Statistically Significant Differences Shown";
footnote "Based on Negative Binomial Regression Model";
proc sgplot data=state_coeffs(where=(significant=1));
    hbar state_code / response=irr fillattrs=(color=blue) 
                     categoryorder=respasc
                     datalabel datalabelattrs=(size=10);
    refline 1 / axis=x lineattrs=(pattern=dash);
    xaxis label="Incidence Rate Ratio (IRR)" min=0;
    yaxis label="State";
    format irr 4.2;
run;
