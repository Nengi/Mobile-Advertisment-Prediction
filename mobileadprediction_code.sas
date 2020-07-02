/* Location to store data */
libname p '/home/u38068025/Projects';

/* read in the data sets */
data train;
	set p.adstrain;
	attrib device_height label="Display Height (in pixels)";
	attrib device_width label="Display Width (in pixels)";
	attrib device_make label="Device Manufacturer";
	attrib device_platform label="Phone OS Type (Andriod/IOS)";
	attrib device_os label="Phone OS Version";
	attrib device_volume label="Device Volume when Ad is displayed";
	attrib resolution label="Display Resolution (pixels per inch)";
	attrib language label="Language settings on device";
	attrib wifi label="Wifi Enabled (Yes = 1, No = 0) ";
	attrib publisher_id label="Publisher Id";
	attrib install label="Customer Installed App (Yes = 1, No = 0)";
run;

proc contents data = train;
run;

data test;
	set p.adstest;
run;

/*exploratory analysis in the training data set */
/* percentage of app installations */
proc contents data=train;
run;

proc freq data=train;
	table install / nocum plots=freqplot(twoway=stacked orient=vertical);
run;

/* 0.81% of apps are installed  */
/* percentage of app installations by wifi */
proc freq data=train;
	table install * wifi /norow nocol nofreq chisq plots=freqplot(twoway=stacked orient=vertical);
run;

/* 0.61% of apps are installed with wifi on, 0.2% had wifi off, chisq is significant */
/* app installations by language */
proc freq data=train;
	table language*install /nocum chisq;
run;

proc freq data=train nlevels;
table language;
run;

/* chi square test suggests language and install are independent. Retain a grouping of
settings that have us_english, other_english and other languages*/
data train1;
	set train;
	l1=substr(language, 1, 2);
	l2=substr(language, 1, 5);

	if l1="en" then
		do;

			if l2="en-US" then
				do;
					lang_en_us=1;
					lang_en_other=0;
					lang_other=0;
				end;
			else
				do;
					lang_en_us=0;
					lang_en_other=1;
					lang_other=0;
				end;
		end;
	else
		do;
			lang_en_us=0;
			lang_en_other=0;
			lang_other=1;
		end;
	drop language l1 l2;
run;

proc freq data=train1;
	table lang_en_us*install /norow nocol nocum chisq chisq 
		plots=freqplot(twoway=stacked orient=vertical);
	table lang_en_other*install /norow nocol nocum chisq;
	table lang_other*install /norow nocol nocum chisq;
run;

/* only chisq for us english settings is significant */
/* Percentage of app installations by screen orientation
create a new train data set to have 0 for potrait and 1 for landscape depending on device width and height
drop device_height and device_width it is represented by lscp and resolution */
data train2;
	set train1;

	if device_height > device_width then
		landscape=0;
	else
		landscape=1;
	drop device_height device_width;
run;

/* calculate frequency of orientation by install */
proc freq data=train2;
	table install * landscape /norow nocol chisq plots=freqplot(twoway=stacked 
		orient=vertical);
run;

/* chisq is insignificant */
/* Percentage of app installations by phone type. Majority of the consumers are apple customers */
proc freq data=train2;
	table install * device_platform /norow nocol chisq 
		plots=freqplot(twoway=stacked orient=vertical);
run;

/* create levels for the andriod os*/
proc sql;
	select distinct device_os from train;
	run;

proc freq data=train2;
	table device_os*device_platform /nofreq nopercent nocum;
run;

data train2;
	set train2;
	d=substr (device_os, 1, 1);

	if d="1" then
		d="10";
run;

data train2;
	set train2;
	d1=cats (device_platform, d);
run;

data train2;
	set train2;
	iOS10=d1 in ("iOS10");
	iOS9=d1 in ("iOS9");
	iOS8=d1 in ("iOS8");
	iOS7=d1 in ("iOS7");
	drop d d1 device_platform device_os;
run;

/* group phone devices based on the apple devices since they have the most installs */
proc sql;
	select distinct device_make from train2;
	run;

proc freq data=train2;
	table device_make*install / nocum norow nocol;
run;

data train3;
	set train2;
	p1=substr(device_make, 1, 7);

	if p1="iPhone9" or p1="iPhone8" or p1="iPhone7" then
		retina_hd=1;
	else
		retina_hd=0;
	p2=substr(device_make, 1, 6);

	if p2="iPhone" then
		iPhone=1;
	else
		iPhone=0;
	p3=substr(device_make, 1, 4);

	if p3="iPad" then
		iPad=1;
	else
		iPad=0;
	drop device_make p1 p2 p3;
run;

/* Frequency of installs based on device groupings */
proc freq data=train3;
	table retina_hd*install /norow nocum nocol plots=freqplot(twoway=stacked 
		orient=vertical);
run;

proc freq data=train3;
	table iPhone*install /norow nocum nocol missprint 
		plots=freqplot(twoway=stacked orient=vertical);
run;

proc freq data=train3;
	table iPad*install /norow nocum nocol missprint plots=freqplot(twoway=stacked 
		orient=vertical);
run;

/* device volume */
proc freq data=train3;
	table device_volume*install / nocol norow nocum chisq;
	table resolution*install / nocol norow nocum chisq;
run;

proc sgpanel data=train3;
	panelby install ;
	vbox device_volume  ;
run;

proc sgpanel data=train3;
	panelby install;
	vbox resolution;
run;

/* Percentage of app installations by Publisher */
proc freq data=train3 nlevels;
	table publisher_id*install / list nocol norow nocum chisq 
		out=pub_install (drop=percent);
run;

proc freq data=pub_install;
	table install /nocum nopercent plots=freqplot(twoway=stacked orient=vertical);
run;


proc freq data=train3;
	table publisher_id / nocum chisq out=total (rename=(count=total));
run;

/* Only 57 publishers had installations in the training data set. chisq is signifcant */
/* calculate publisher install rate */
data pub_install1;
	merge pub_install total;
	by publisher_id;
	drop percent;
run;

data pub_install2;
	set pub_install1;
	by publisher_id;

	if first.publisher_id=1 and last.publisher_id=0 then
		delete;

	if install=1 then
		publisher_install_rate=count/total;
	else
		publisher_install_rate=0;
	drop count total install;
run;

proc sort data=train3;
	by publisher_id;
run;

data train4 (drop=publisher_id);
	merge train3 pub_install2;
	by publisher_id;
	install_rate_sq=publisher_install_rate * publisher_install_rate;
run;


proc export
data=train4 
OUTFILE="/home/u38068025/Projects/smpl.csv"
DBMS=csv;

* Smote - This is Performed With Python's Scikit-Learn;
proc import datafile= "/home/u38068025/Projects/train_smote.csv"
	dbms = csv
	out = p.smote
	replace;
	getnames=YES;
run;

data smote (drop=Var1);
	set p.smote;
run;

proc freq data=smote;
	table install / nocum plots=freqplot(twoway=stacked orient=vertical);
run;



/* Prepare test dataset by replicating changes done in training set */
data test1;
	set test;
	d=substr (device_os, 1, 1);

	if d="1" then
		d="10";
run;

data test1;
	set test1;
	d1=cats (device_platform, d);
run;

data test1;
	set test1;
	iOS10=d1 in ("iOS10");
	iOS9=d1 in ("iOS9");
	iOS8=d1 in ("iOS8");
	iOS7=d1 in ("iOS7");
	drop d d1 device_platform device_os;
run;

data test1;
	set test1;

	/* set language */
	l1=substr(language, 1, 2);
	l2=substr(language, 1, 5);

	if l1="en" then
		do;

			if l2="en-US" then
				do;
					lang_en_us=1;
					lang_en_other=0;
					lang_other=0;
				end;
			else
				do;
					lang_en_us=0;
					lang_en_other=1;
					lang_other=0;
				end;
		end;
	else
		do;
			lang_en_us=0;
			lang_en_other=0;
			lang_other=1;
		end;

	/* set screen orientation dummy */
	if device_height > device_width then
		landscape=0;
	else
		landscape=1;

	/*set phone category dummy */
	p1=substr(device_make, 1, 7);

	if p1="iPhone9" or p1="iPhone8" or p1="iPhone7" then
		retina_hd=1;
	else
		retina_hd=0;
	p2=substr(device_make, 1, 6);

	if p2="iPhone" then
		iPhone=1;
	else
		iPhone=0;
	p3=substr(device_make, 1, 4);

	if p3="iPad" then
		iPad=1;
	else
		iPad=0;
	drop language device_height device_width device_make p1 p2 p3 l1 l2;
run;

/* calculate publisher install rate */
proc freq data=test1;
	table publisher_id*install / list nocol norow nocum 
		out=pub_test (drop=percent);
run;

proc freq data=test1;
	table publisher_id / nocum out=test_total (rename=(count=total));
run;

data pub_test1;
	merge pub_test test_total;
	by publisher_id;
	drop percent;
run;

data pub_test2;
	set pub_test1;
	by publisher_id;

	if first.publisher_id=1 and last.publisher_id=0 then
		delete;

	if install=1 then
		publisher_install_rate=count/total;
	else
		publisher_install_rate=0;
	drop count total install;
run;

proc sort data=test1;
	by publisher_id;
run;

data test2 (drop=publisher_id);
	merge test1 pub_test2;
	by publisher_id;
	install_rate_sq=publisher_install_rate * publisher_install_rate;
run;



/* model1 - base logistic regression model interaction non device specific*/
ods trace on;
ods graphics on;
proc logistic data=smote rocoptions(crossvalidate) plots(only)=roc(id=obs);
	model install (event="1")= publisher_install_rate|install_rate_sq|device_volume|landscape
	|wifi|retina_hd|resolution|lang_en_us|lang_en_other /selection=stepwise slentry=0.5 slstay=0.3 outroc=train_roc ctable;
	score data = test2 out=model_pred1 outroc=test_roc;
	roc;
run;
ods graphics off;
ods trace off;


/* model2 - logistic regression model with interaction   */
ods trace on;
ods graphics on;
proc logistic data=smote rocoptions(crossvalidate) plots(only)=roc(id=obs) outmodel=final_model;
	model install (event="1")= resolution publisher_install_rate lang_en_us landscape wifi install_rate_sq 
	 								 resolution*publisher_install_rate publisher_install_rate*landscape
	 								 resolution*publisher_install_rate*landscape / outroc=train_roc ctable;
	score data = test2 out=model_pred2 outroc=test_roc;
	roc;
run;
ods graphics off;
ods trace off;

/* Save the output of ctable and extract the false positives and false negatives */
proc import datafile= "/home/u38068025/Projects/ct2.csv"
	dbms = csv
	out = p.ct2;
	getnames=YES;
run;


/* Calculate Cost  
 formula for cost at a given rate is  false positive + (rate * false negative)*/
data totalcost;
	set p.ct2;
	cost25= positive + (25 * (negative/100));
	cost50= positive + (50 * (negative/100));
	cost100= positive + (100 * (negative/100));
	cost200= positive + (200 * (negative/100));
run;

/* Get minimum cost */
proc sql;
	create table mincost25 as select probability, mincost from
	(select prob as probability, min(cost25) as mincost, negative from totalcost 
		having cost25=min(cost25)) having negative=min(negative);
	run;
quit;

proc sql;
	create table mincost50 as select probability, mincost from
	(select prob as probability, min(cost50) as mincost, negative from totalcost 
		having cost50=min(cost50)) having negative=min(negative);
	run;
quit;

proc sql;
	create table mincost100 as select probability, mincost from
	(select prob as probability, min(cost100) as mincost, negative from totalcost 
		having cost100=min(cost100)) having negative=min(negative);
	run;
quit;

proc sql;
	create table mincost200 as select probability, mincost from
	(select prob as probability, min(cost200) as mincost, negative from totalcost 
		having cost200=min(cost200)) having negative=min(negative);
	run;
quit;

data threshold;
	set mincost25 mincost50 mincost100 mincost200;
run;

proc print data=threshold;
	title 'Proabilities and Minimum Costs At 25, 50, 100, 200';
run;

/* classify */
data classify;
	set model_pred2;
	if P_1 > 0.7 then
		show_ad="yes";
	else
		show_ad="no";
	keep install P_1 show_ad run;
	
proc freq data = classify;
 	table install*show_ad / nocol norow nocum nofreq ;
 run;