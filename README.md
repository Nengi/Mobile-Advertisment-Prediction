# Mobile Advertisment Prediction

This project aims to predict probability of a user installing an app after seeing a mobile adverstisment. This project was for the Predictive Analytics course at the University of Texas at Dallas

## Project Details
The dataset was an imbalanced dataset with 0.81% of observed cases. Logistic regression was implemented was in SAS with a prediction accuracy of 69%. An update was made Random Oversampling package in R with an improved accuracy of 71%. Analysis of the dataset in SAS can be viewed here

## Example Code in SAS
```
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

```

