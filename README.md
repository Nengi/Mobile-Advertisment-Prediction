# Mobile Advertisment Prediction

This project aims to predict the probability of a user installing an app after seeing a mobile adverstisment. The project was implemented as part of the Predictive Analytics course at the University of Texas at Dallas

## Project Details
The dataset was imbalanced with 0.81% of the data having the observed case of a user installing the application. Logistic regression was implemented in SAS with a prediction accuracy of 69%. An update was made Random Oversampling package in R with an improved accuracy of 71%. Analysis of the dataset in SAS can be viewed in the pdf document attached.

## Technology Used
- SAS 
- R

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

## Example Code in R
```
lgmdl <- glm(install~ resolution + publisher_install_rate+ lang_en_us+ landscape+ wifi+ install_rate_sq + resolution*publisher_install_rate+ publisher_install_rate*landscape + resolution*publisher_install_rate*landscape, data = train1,family="binomial") 

summary(lgmdl)

test <- read.csv("test.csv")
test[,cols] <- lapply(test[,cols],as.factor)

predlg <- predict(lgmdl, newdata= test,type="response")
roc.curve(test$install, predlg)
```
