create database army_analytics;
use army_analytics;

-- 1
select *
from army_personnel_data;

-- 2
select SOLDIER_ID, LAST_NAME, FIRST_NAME, `RANK`, MOS_TITLE  -- make sure use " ` "
from army_personnel_data;

-- 3
select *
from army_personnel_data
where `rank` = "SGT";

-- 4
select SOLDIER_ID, LAST_NAME, `rank`, ACFT_TOTAL_SCORE
from army_personnel_data
where `rank` = "SGT"
	and ACFT_STATUS = "PASS";
    
-- 5
select SOLDIER_ID, LAST_NAME, `rank`, ACFT_TOTAL_SCORE
from army_personnel_data
order by ACFT_TOTAL_SCORE desc
limit 20;

-- 6
select gender, count(*) as soldier_count
from army_personnel_data
group by gender;

-- 7
select sum(TOTAL_MONTHLY_PAY_USD) as salary,
	avg(TOTAL_MONTHLY_PAY_USD) as avg_pay,
    min(TOTAL_MONTHLY_PAY_USD) as min_pay,
    max(TOTAL_MONTHLY_PAY_USD) as max_pay
from army_personnel_data;

-- 8 AVG ACFT by Rank
select `rank`,
	count(*) as soldiers,
    round(avg(ACFT_TOTAL_SCORE),1) as avg_acft,
    sum(case when ACFT_STATUS ="PASS" then 1
    else 0
    end) as pass_count
from army_personnel_data
group by `rank`
order by avg_acft desc;

-- 9 ACFT pass rate by Brigade
select BRIGADE, count(*) as total,
	round(100.0 * sum( case when ACFT_STATUS="PASS" then 1 else 0 end)/count(*),1) as pass_pct
from army_personnel_data
group by BRIGADE;

-- 10 Deployment Summary
select DEPLOYMENT, THEATER, count(*) as soldiers,
	round(avg(DEPLOY_MONTHS),1) as avg_months
from army_personnel_data
group by DEPLOYMENT, THEATER
order by soldiers desc;

-- 11 Pay Analysis by Pay Grade
select PAY_GRADE, count(*) as headcount,
	round(avg(BASE_PAY_USD),0) as avg_base,
    round(avg(TOTAL_MONTHLY_PAY_USD),0) as avg_total,
    round(avg(TOTAL_MONTHLY_PAY_USD) *12,0) as avg_annual
from army_personnel_data
group by PAY_GRADE
order by avg_base desc;    

-- 12 Soldiers approaching ETS (retention risk)
select SOLDIER_ID, LAST_NAME, `rank`, BRIGADE, DAYS_UNTIL_ETS,
	case when DAYS_UNTIL_ETS < 0 then "Separated"
		when DAYS_UNTIL_ETS < 90 then "Iminent ETS"
        when DAYS_UNTIL_ETS < 180 then "ETS Soon"
        else "Retained"
	end as est_risk
from army_personnel_data
where DAYS_UNTIL_ETS <= 180
order by DAYS_UNTIL_ETS asc;

-- 13 Weapon Qualification Breakdown
select WEAPON_QUALIFICATION, count(*) as count,
	round(avg(WEAPON_SCORE),1) as avg_score,
	round(100.0*count(*)/sum(count(*)) over(),1) as pct_of_total
from army_personnel_data
group by WEAPON_QUALIFICATION
order by avg_score desc;

-- 14 Top ACFT performers per Brigade
select * from (
	select BRIGADE, LAST_NAME, FIRST_NAME, `rank`, ACFT_TOTAL_SCORE, 
	rank() over (partition by BRIGADE order by ACFT_TOTAL_SCORE desc) as brigade_rank
from army_personnel_data
) ranked
where brigade_rank <=3
order by BRIGADE, brigade_rank;

-- 15 Cumulative payroll by Seniority
select YEARS_OF_SERVICE, TOTAL_MONTHLY_PAY_USD, sum(TOTAL_MONTHLY_PAY_USD) 
	over (order by YEARS_OF_SERVICE
    rows between unbounded preceding and current row
    ) as running_total
from army_personnel_data
order by YEARS_OF_SERVICE;

-- 16 Combat Veteran above AVG ACFT
with combat_vets as (
	select *
    from army_personnel_data
    where COMBAT_TOURS > 0
),
avg_scores as (
	select avg(ACFT_TOTAL_SCORE) as army_avg
    from army_personnel_data
)
select cv.SOLDIER_ID, 
		cv.LAST_NAME, 
        cv.`rank`, 
        cv.ACFT_TOTAL_SCORE, 
        av.army_avg, 
        cv.ACFT_TOTAL_SCORE - av.army_avg as score_vs_avg
from combat_vets cv
cross join avg_scores av
where cv.ACFT_TOTAL_SCORE > av.army_avg
order by score_vs_avg desc;

-- 17 Soldiers earning above Brigade AVG
select s.SOLDIER_ID, s.LAST_NAME, s.`rank`,
		s.BRIGADE, s.TOTAL_MONTHLY_PAY_USD,
        brig_avg.avg_pay as brigade_avg_pay,
        s.TOTAL_MONTHLY_PAY_USD - brig_avg.avg_pay as pay_above_avg
from army_personnel_data s
join (
	select BRIGADE, avg(TOTAL_MONTHLY_PAY_USD) as avg_pay
    from army_personnel_data
    group by BRIGADE
) as brig_avg on s.BRIGADE = brig_avg.BRIGADE
where s.TOTAL_MONTHLY_PAY_USD > brig_avg.avg_pay
order by pay_above_avg desc;

 -- 18 Year-over-year promotion gap
select SOLDIER_ID, LAST_NAME, `rank`, LAST_PROMOTION_DATE,
       lag(LAST_PROMOTION_DATE) over (
           order by LAST_PROMOTION_DATE
       ) as prev_promotion,
       DATEDIFF(LAST_PROMOTION_DATE,
           lag(LAST_PROMOTION_DATE) over (
               order by LAST_PROMOTION_DATE
           )
       ) as days_between
from army_personnel_data
order by  days_between desc;

 -- 19 Fitness Quarantile segmentation
 select SOLDIER_ID, LAST_NAME, `rank`, ACFT_TOTAL_SCORE,
	ntile(4) over (order by ACFT_TOTAL_SCORE desc) as fitness_quarantile,
    case ntile(4) over (order by ACFT_TOTAL_SCORE desc)
		when 1 then "Top 25% - Elite"
        when 2 then "Q2 - Above AVG"
        when 3 then "Q3 - Below AVG"
        when 4 then "Bottom 25% - At risk"
	end as fitness_tier
from army_personnel_data
order by fitness_quarantile, ACFT_TOTAL_SCORE desc;