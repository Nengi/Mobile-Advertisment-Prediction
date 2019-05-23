/* Location to store data */
libname p '/folders/myfolders/Project2';

/* read in the data sets */

data train;
	set p.mobileadstraining;
	run;

data test;
	set p.mobileadstest;
	run;
	
	
/*exploratory analysis in the training data set */

/* percentage of app installations */

proc contents data = train;
run;

proc freq data = train;
	table install / nocum plots = freqplot(twoway=stacked orient=vertical);
	run;

/* 0.81% of apps are installed  */


/* percentage of app installations by wifi */
proc freq data = train;
	table install * wifi /norow nocol nofreq chisq plots = freqplot(twoway=stacked orient=vertical);
	run;
/* 0.61% of apps are installed with wifi on, 0.2% had wifi off, chisq is significant */

	
/* app installations by language */
proc freq data = train;
	table language*install /nocum;
	run;

/* chi square test suggests language and install are independent. Retain a grouping of 
   settings that have us_english, other_english and other languages*/
data train1;
	set train;
	l1 = substr(language, 1, 2);
	l2 = substr(language, 1, 5);
	if l1 = "en" then 
		do;
			if l2 = "en-US" then 
				do;
				   lang_en_us = 1;
				   lang_en_other = 0;
					lang_other = 0;
				end;
			else 
				do;
					lang_en_us = 0;
				   lang_en_other = 1;
					lang_other = 0;
				end;
		end;
		else 
			do;
				lang_en_us = 0;
				lang_en_other = 0;
				lang_other = 1;
				end;
	drop language l1 l2 ;
	run;

proc freq data = train1;
	table lang_en_us*install /norow nocol nocum chisq chisq plots = freqplot(twoway=stacked orient=vertical);
	table lang_en_other*install /norow nocol nocum chisq;
	table lang_other*install /norow nocol nocum chisq;
	run;

/* only chisq for us english settings is significant */

/* Percentage of app installations by screen orientation 
   create a new train data set to have 0 for potrait and 1 for landscape depending on device width and height 
   drop device_height and device_width it is represented by lscp and resolution */
data train2;
	set train1;
	if device_height > device_width then landscape = 0;
	else landscape = 1;
	drop device_height device_width;
	run;
/* calculate frequency of orientation by install */
proc freq data = train2;
	table install * landscape /norow nocol chisq plots = freqplot(twoway=stacked orient=vertical);
		run;
/* chisq is insignificant */


/* Percentage of app installations by phone type. Majority of the consumers are apple customers */
proc freq data = train2;
	table install * device_platform /norow nocol chisq plots = freqplot(twoway=stacked orient=vertical);
	run;
	
/* create levels for the andriod os*/
proc sql;
select distinct device_os from train;
run;

proc freq data = train2;
table device_os*device_platform /nofreq nopercent nocum;
run;

data train2;
	set train2;
	d = substr (device_os, 1, 1);
	if d = "1" then d = "10";
	run;

data train2;
	set train2;
	d1 = cats (device_platform, d);
	run;

data train2;
	set train2;
	iOS10 = d1 in ("iOS10");
	iOS9 = d1 in ("iOS9");
	iOS8 = d1 in ("iOS8");
	iOS7 = d1 in ("iOS7");
	drop d d1 device_platform device_os;
	run;
	
/* group phone devices based on the apple devices since they have the most installs */
proc sql;
select distinct device_make from train2;
run;

proc freq data = train2;
table device_make*install / nocum norow nocol;
run;
	
data train3;
	set train2;	
	p1 = substr(device_make, 1, 7);
	if p1 = "iPhone9" or p1 = "iPhone8" or  p1 = "iPhone7" then retina_hd = 1;
	else retina_hd = 0;
	p2 = substr(device_make, 1, 6);
	if p2 = "iPhone" then iPhone = 1; else iPhone = 0;
	p3 = substr(device_make, 1, 4);
	if p3 = "iPad" then iPad = 1; else iPad = 0;
	drop  device_make p1 p2 p3;
	run;

/* Frequency of installs based on device groupings */

proc freq data= train3;
table retina_hd*install /norow nocum nocol plots = freqplot(twoway=stacked orient=vertical);
run;

proc freq data= train3;
table iPhone*install /norow nocum nocol missprint plots = freqplot(twoway=stacked orient=vertical);
run;

proc freq data= train3;
table iPad*install /norow nocum nocol missprint plots = freqplot(twoway=stacked orient=vertical);
run;


/* device volume */
proc freq data = train3;
	table device_volume*install / nocol norow nocum;
	table resolution*install / nocol norow nocum;
	run;

/* Percentage of app installations by Publisher */
proc freq data = train3;
	table publisher_id*install / list nocol norow nocum chisq out = pub_install (drop = percent);
	run;

proc freq data = pub_install;
	table install /nocum nopercent plots = freqplot(twoway=stacked orient=vertical);
	run;
/* Only 57 publishers had installations in the training data set. chisq is signifcant */
	
/* calculate publisher install rate */
proc freq data = train3;
	table publisher_id / nocum out = total (rename = (count = total));
	run;

data pub_install1;
	merge pub_install total;
	by publisher_id;
	drop percent;
	run;

data pub_install2;
	set pub_install1;
	by publisher_id;
	if first.publisher_id = 1 and last.publisher_id = 0 then delete;
	if install = 1 then publisher_install_rate = count/total;
	else publisher_install_rate = 0;
	drop count total install;
	run;

proc sort data = train3;
	by publisher_id;
	run;
	
data train4 (drop = publisher_id);
	merge train3 pub_install2;
	by publisher_id;
	install_rate_sq = publisher_install_rate * publisher_install_rate;
	run;

/*Estimating the model */

/* model1 - main effects model */
proc logistic data = train4;
	 model install (event = "1") = resolution publisher_install_rate wifi landscape device_volume retina_hd
	 							   iOS10 iOS9 iOS8 iOS7 iPhone iPad lang_en_us lang_en_other/firth;
	 output out= mdl1 p=phat lower=lcl upper=ucl
      predprob=(individual crossvalidate);
   run;

/* model 2 - main effects and interaction effects - not device specific */	
proc logistic data = train4;
	 model install (event = "1") =  resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 								 resolution*publisher_install_rate publisher_install_rate*landscape
	 								 resolution*publisher_install_rate*landscape/ firth;
     output out= mdl2 p=phat lower=lcl upper=ucl
     predprob=(individual crossvalidate);
   run; 
   
/* model 3 - main effects and interaction effects device specific */	
proc logistic data = train4;
	 model install (event = "1") = resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 							   resolution*publisher_install_rate publisher_install_rate*landscape
	 							   resolution*publisher_install_rate*landscape
	 							   wifi*landscape lang_en_us*landscape wifi*landscape*lang_en_us 
	 							   iPad iPad*publisher_install_rate iPad*landscape
	 							   iPad*landscape*publisher_install_rate   
	 							   / firth;
     output out= mdl3 p=phat lower=lcl upper=ucl
     predprob=(individual crossvalidate);
   run; 
   
   
/*	Estimate ROC curves on test data	*/

/* Prepare test dataset by replicating changes done in training set */

data test1;
	set test;
	d = substr (device_os, 1, 1);
	if d = "1" then d = "10";
	run;

data test1;
	set test1;
	d1 = cats (device_platform, d);
	run;

data test1;
	set test1;
	iOS10 = d1 in ("iOS10");
	iOS9 = d1 in ("iOS9");
	iOS8 = d1 in ("iOS8");
	iOS7 = d1 in ("iOS7");
	drop d d1 device_platform device_os;
	run;
	

data test1;
	set test1; 
	/* set language */
l1 = substr(language, 1, 2);
	l2 = substr(language, 1, 5);
	if l1 = "en" then 
		do;
			if l2 = "en-US" then 
				do;
				   lang_en_us = 1;
				   lang_en_other = 0;
					lang_other = 0;
				end;
			else 
				do;
					lang_en_us = 0;
				   lang_en_other = 1;
					lang_other = 0;
				end;
		end;
		else 
			do;
				lang_en_us = 0;
				lang_en_other = 0;
				lang_other = 1;
				end;
	/* set screen orientation dummy */
	if device_height > device_width then landscape = 0;
	else landscape = 1;
	/*set phone category dummy */
	p1 = substr(device_make, 1, 7);
	if p1 = "iPhone9" or p1 = "iPhone8" or  p1 = "iPhone7" then retina_hd = 1;
	else retina_hd = 0;
	p2 = substr(device_make, 1, 6);
	if p2 = "iPhone" then iPhone = 1; else iPhone = 0;
	p3 = substr(device_make, 1, 4);
	if p3 = "iPad" then iPad = 1; else iPad = 0;
	drop language device_height device_width device_make p1 p2 p3 l1 l2;
	run;

/* calculate publisher install rate */
proc freq data = test1;
	table publisher_id*install / list nocol norow nocum out = pub_test (drop = percent);
	run;
	
proc freq data = test1;
	table publisher_id / nocum out = test_total (rename = (count = total));
	run;

data pub_test1;
	merge pub_test test_total;
	by publisher_id;
	drop percent;
	run;

data pub_test2;
	set pub_test1;
	by publisher_id;
	if first.publisher_id = 1 and last.publisher_id = 0 then delete;
	if install = 1 then publisher_install_rate = count/total;
	else publisher_install_rate = 0;
	drop count total install;
	run;

proc sort data = test1;
	by publisher_id;
	run;
	
data test2 (drop = publisher_id);
	merge test1 pub_test2;
	by publisher_id;
	install_rate_sq = publisher_install_rate * publisher_install_rate;
	run;


/* Predict the test dataset using the models and plot the ROC */

/* model1 */
ods trace on;
proc logistic data = train4;
	model install (event='1') = resolution publisher_install_rate wifi /firth ctable;
	score data = test2 out = model_pred1;
	ods output classification = ct1(keep = problevel falsepositive falsenegative);
	run;
ods trace off;

proc logistic data = model_pred1 plots=roc(id=prob) ;
	model install (event='1') = resolution publisher_install_rate wifi/nofit ctable;
	roc pred = p_1;
	output out = pred1 p = phat1;
	run;
	
/* model2 */
ods trace on;
proc logistic data = train4;
	model install (event='1') = resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 								 resolution*publisher_install_rate publisher_install_rate*landscape
	 								 resolution*publisher_install_rate*landscape /firth ctable;
	score data = test2 out = model_pred2;
	ods output classification = ct2(keep = problevel falsepositive falsenegative);
	run;
ods trace off;

proc logistic data = model_pred2 plots=roc(id=prob);
	model install (event='1') = resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 								 resolution*publisher_install_rate publisher_install_rate*landscape
	 								 resolution*publisher_install_rate*landscape/nofit;
	roc pred = p_1;
	output out = pred2 p = phat2;
	run;


/* model3 */
proc logistic data = train4;
	model install (event='1') = resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 							   resolution*publisher_install_rate publisher_install_rate*landscape
	 							   resolution*publisher_install_rate*landscape
	 							   wifi*landscape lang_en_us*landscape wifi*landscape*lang_en_us 
	 							   iPad iPad*publisher_install_rate iPad*landscape
	 							   iPad*landscape*publisher_install_rate  /firth ctable;
	score data = test2 out = model_pred3;
	ods output classification = ct3(keep = problevel falsepositive falsenegative);
	run;
ods trace off;

proc logistic data = model_pred3 plots=roc(id=prob);
	model install (event='1') = resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 							   resolution*publisher_install_rate publisher_install_rate*landscape
	 							   resolution*publisher_install_rate*landscape
	 							   wifi*landscape lang_en_us*landscape wifi*landscape*lang_en_us 
	 							   iPad iPad*publisher_install_rate iPad*landscape
	 							   iPad*landscape*publisher_install_rate/nofit;
	roc pred = p_1;
	output out = pred3 p = phat3;
	run;


/* Calculate Cost  */

data totalcost;
	set ct2;
	cost25 = FalsePositive + (25 * FalseNegative);
	cost50 = FalsePositive + (50 * FalseNegative);
	cost100 = FalsePositive + (100 * FalseNegative);
	cost200 = FalsePositive + (200 * FalseNegative);
	run;

/* Get minimum cost */
proc sql;
create table mincost25 as 
select probability, mincost from
	(select problevel as probability, min(cost25) as mincost 
	from  totalcost
	having cost25 = min(cost25))
	having probability = min(probability);
	run;
	quit;

proc sql;
create table mincost50 as 
select probability, mincost from
	(select problevel as probability, min(cost50) as mincost 
	from  totalcost
	having cost50 = min(cost50))
	having probability = min(probability);

proc sql;
create table mincost100 as
select probability, mincost from
	(select problevel as probability, min(cost100) as mincost 
	from  totalcost
	having cost100 = min(cost100))
	having probability = min(probability);
	run;
	quit;
 
 proc sql;
create table mincost200 as 
select probability, mincost from
	(select problevel as probability, min(cost200) as mincost 
	from  totalcost
	having cost200 = max(cost200))
	having probability = min(probability);
	run;
	quit;

data threshold;
set mincost25 mincost50 mincost100 mincost200;
run; 	
		
proc print data = threshold;
title 'Proabilities and Minimum Costs At 25, 50, 100, 200';
run;

/* classify */

data classify;
	set model_pred2;
	if P_1 > 0.34 then show_ad = "yes"; else show_ad = "no";
	keep install P_1 show_ad
	run;	
	





