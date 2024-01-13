
// Nov. 22, 2023
********************************************************************
********************************************************************
* To be consistent with the Data Task instruction, I started with secion 2. 

* Theis code file has 3 parts:
* - Part 1 Data Cleaning
* - Part 3 Analyze Patterns across 4 Years
* - Part 4 Analyze Pattern within Each Year

************************Part 1 Data Cleaning***********************
log using "$logs/dataprep.smcl", replace


import delimited "$data/ .csv",clear
import excel auto1.xls, firstrow clear

sysuse auto,clear
label define repair 1 "好" 2 "较 好" 3 "中" 4 "较差" 5 "差"
label values rep78 repair

tabstat price weight length, s(mean sd p25 med p75 min max) c(s) f(%6.2f) by(foreign)

// recode var
sort wage
gen g_wage = group(5)
recode age (min/39 = 1) (39/42 = 2) (42/max = 3), ///
gen(g_age)

// gen xgroup
ssc install xgroup
xgroup race married, gen(race_marr2) label lname(race_marr_lab)

// different 'sum' in gen and egen

help collapse
sysuse nlsw88.dta,clear
collapse (mean) wage hours ///
(count) n_w=wage n_h=hours, ///
by(industry)

// bar graph
sysuse nlsw88.dta, clear
graph bar (mean) wage, over(smsa) over(married) over(collgrad)
graph hbar (mean) hours, over(union) over(married) ///
over(race) percent asyvars
graph bar wage hours, over(race) over(married) stack
graph box wage, over(race)

// duplicate obs
sysuse nlsw88.dta, clear
isid race age
isid idcode

duplicates list race married in 1/20
duplicates report race married occupation
duplicates tag race married occupation, gen(rm_dtag)
duplicates drop race married occupation, force

// missing values
misstable summarize
drop if missing(grade,indus,occup,union,hours,tenure)

mvdecode _all, mv(-97 -999)



// winsor
winsor wage, gen(wage_w) p(0.025)
winsor2 wage, cut(2.5 97.5) trim
winsor2 wage, cut(0 97.5) trim suffix(_trh)


reshape long inc ue, i(id) j(year)
reshape wide inc u@e, i(id) j(year)

// text variable management
destring code, gen(code1) ignore(" ")
destring leverage, gen(lev) percent
destring year date size lev, replace ignore("-/,%")

encode gov, gen(gov1)
tostring year day, replace
tostring date_pub, gen(date1)

gen year = substr(date1, 1, 4)
gen month = substr(date1, 5, 2)
gen day = substr(date1, 7, 2)

decode gender,generate(gender1)

split year, parse(-)
split date,parse(/) destring ignore("/")

// frequently used functions
lower("AbCDef")
proper("mR. joHn a. sMitH")
strmatch("C51", "C")
trim(" Hello World! ")
subinstr("内 蒙 古 自治区", " ", "", .)


// datetime
gen year = int(date/10000)
tostring date, gen(date1)
gen year1 = substr(date1,1,4)
gen year2 = real(year1)

gen month1 = substr(date1,5,2)
gen month2= real(month)

gen day1 = substr(date1,7,2)
gen day2 = real(day)

gen year3 = real(substr(date1, 1, 4))
gen month3 = real(substr(date1, 5, 2))
gen day3 = real(substr(date1, 7, 2))

gen province = word(location, 1)
gen city = word(location, 2)


// macro
local a = 5
local b "Hello!"

sysuse auto, clear
local var price weight rep78 length

// ttest
ttest price, by(foreign)
sdtest mpg1 == mpg2
ttest mpg1 == mpg2, unpaired
ttest mpg1==mpg2

sysuse auto,clear
ttable2 price wei len mpg, by(foreign) f(%6.2f)

sysuse auto,clear
local var price wei len mpg
qui estpost ttest `var´, by(foreign)
esttab ., cell("mu_1(fmt(2)) mu_2(fmt(2)) b(star fmt(2)) t(fmt(2))") ///
starlevels(* 0.10 ** 0.05 *** 0.01) replace noobs compress ///
title(esttab_Table: T_test)


// Descriptive Statistics Table
outreg2 using Desc3, sum(detail) replace word ///
keep(price wei len mpg rep78) eqkeep(N mean sd min p50 max) ///
fmt(f) sortvar(wage age grade) ///
title(outreg2_Table: Descriptive statistics)

estpost summarize price wei len mpg rep78, detail
esttab using Desc4.rtf, ///
cells("count mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p50(fmt(2)) max(fmt(2))") ///
noobs compress replace title(esttab_Table: Descriptive statistics)


// ols regress
sysuse auto, clear
reg price weight mpg turn foreign, robust
predict yhat，xb //price的拟合值
predict e, residual //残差
vce //获取变量的方差—协方差矩阵

twoway (rspike price yhat_p mpg ) ///
(lfit price mpg) ///
(scatter price mpg ), ///
legend(label(1 "观察值到拟合线的距离") label(2 "拟合线") row(1) size(small))


sysuse nlsw88, clear
reg wage age married occupation
est store m1
reg wage age married collgrad occupation
est store m2
xi: reg wage age married collgrad occupation i.race
est store m3
esttab m1 m2 m3 using ols.rtf, scalar(r2 r2_a N F) compress ///
star(* 0.1 ** 0.05 *** 0.01) ///
b(%6.3f) t(%6.3f) r2(%9.3f) ar2 ///
mtitles("OLS-1" "OLS-2" "OLS-3") ///
title(esttab_Table: regression result)

esttab m1 m2 m3 using ols.tex, replace ///
star( * 0.10 ** 0.05 *** 0.01 ) compress ///
b(%6.3f) t(%6.3f) r2(%9.3f) ar2 ///
mtitles("OLS-1" "OLS-2" "OLS-3") ///
title(esttab_Table: regression result) ///
booktabs page width(\hsize)

// regression by group
sysuse auto, clear
eststo clear
eststo: qui reg weight mpg
eststo: qui reg weight mpg foreign
eststo: qui reg price weight mpg
eststo: qui reg price weight mpg foreign
esttab using mgroups.tex, replace ///
star(* 0.1 ** 0.05 *** 0.01) ///
compress nogaps ///
title(An Illustration of mgroup() in esttab) ///
mgroups("Group A" "Group B", ///
pattern(1 0 1 0) span ///
prefix(\multicolumn{@span}{c}{) suffix(}) ///
erepeat(\cmidrule(lr){@span}) ) ///
booktabs page(dcolumn) alignment(D{.}{.}{-1})


// est add
sysuse nlsw88.dta, clear
global xx "ttl_exp married south hours tenure age i.industry"
qui reg wage $xx if race==1
estadd local Industry "Yes"
estadd local Occupation "No"
est store m1
qui reg wage $xx if race==2
estadd local Industry "Yes"
estadd local Occupation "No"
est store m2
qui reg wage $xx i.occupation if race==1
estadd local Industry "Yes"
estadd local Occupation "Yes"
est store m3
qui reg wage $xx i.occupation if race==2
estadd local Industry "Yes"
estadd local Occupation "Yes"
est store m4

local m "m1 m2 m3 m4"
esttab `m´, mtitle(White Black White Black) b(%6.3f) nogap compress ///
star(* 0.1 ** 0.05 *** 0.01) ///
drop(*.industry *.occupation) ///
ar2 scalar(N Industry Occupation)


// dummy variables
use Nations2.dta,clear
tab region,gen(reg)

qui reg logco2 urban reg4 urb_reg4
qui reg logco2 c.urban i.reg4 c.urban#i.reg4
qui reg logco2 c.urban##i.reg4
* factor-variable :
* i. indicator variables
* c. continuous variables
* # an interaction between two variables
* ## factorial interaction which automatically includes all the lower-level
* interactions involving those variables

qui margins, at(urban = (10(30)100) reg4 = (0 1)) vsquish
marginsplot, ytitle("Log{subscript:10}(CO{subscript:2} per capita)") xlabel(10(30)100)

// binary outcome models
probit y x1 x2 x3,r
logit y x1 x2 x3,or vce(cluster clustvar)

predict yhat
estat clas

margins,dydx(*) //计算所有解释变量的平均边际效应
margins,dydx(*) atmeans //计算所有解释变量样本均值处边际效应
margins,dysx(*) at(x1=0) //计算所有解释变量在x1=0处边际效应
margins,dydx(x1) //计算解释变量x1的平均边际效应
margins,eyex(*) //计算平均弹性
margins,eydx(*) //计算平均半弹性，x变化1单位使y变化百分之几
margins,dyex(*) //计算平均半弹性，x变化1%使y变化几个单位

logit work age married children education,nolog vce(cluster age)

// Oaxaca-Blinder Decomposition
oaxaca lnwage educ exper tenure, by(female) weight(1)

// iv estimator
ivregress 2sls y x1 (x2 = z1 z2)
ivregress 2sls y x1 (x2 = z1 z2), r first

estat overid

ivreg2 lw s expr tenure rns smsa (iq = med kww mrt age), r orthog (mrt age)
ivregress 2sls lw s expr tenure rns smsa (iq=med kww), r first

qui reg lw s expr tenure rns smsa med, r
est store m1
qui reg lw s expr tenure rns smsa kww, r
est store m2
qui reg lw s expr tenure rns smsa med kww, r
est store m3
esttab m1 m2 m3, ///
mtitle("reduced form:med" "reducedform:kww" "reducedform:med,kww") ///
b(%6.3f) nogap compress ///
star(* 0.1 ** 0.05 *** 0.01) ///
ar2 order(med kww)


// RDD
rename demmv X
rename demvoteshfor2 Y
gen T=.
replace T=0 if X<0 & X!=.
replace T=1 if X>=0 & X!=.
gen ranwin=(X>=0)

twoway (scatter Y X, msize(vsmall) ///
mcolor(black) xline(0, lcolor(black))), ///
graphregion(color(white)) ytitle(Outcome) ///
xtitle(Score)


* Three Steps:
* 1 Graph the data for visual inspection
* 2 Estimate the treatment effect using regression methods
* 3 Run checks on assumptions underlying research design




//END
log close
exit