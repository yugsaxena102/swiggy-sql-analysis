/*
===============================================================================
  Swiggy Restaurant Data Analysis Project
  Author      : Yug
  Dataset     : 61,356 Restaurants | 534 Cities | 108 Cuisines
  Description : End-to-end SQL analysis of Swiggy restaurant data to uncover
                market gaps, identify top-performing cuisines, benchmark city
                pricing, and recommend data-driven expansion strategies.
  DB Flavor   : MySQL / PostgreSQL Compatible
===============================================================================
*/


-- ============================================================================
-- SECTION 1 — DATA CLEANING & STANDARDIZATION
-- ============================================================================

-- Q1. Fix leading/trailing whitespace in the city column
-- Issue: Importing the CSV introduced leading spaces in some city names.
--        For example, ' Bangalore' was stored differently from 'Bangalore',
--        causing GROUP BY to treat them as two separate cities.
-- Fix  : Apply TRIM() across the entire column to strip all whitespace.
UPDATE restaurants
SET city = TRIM(city);

-- Analysis: This fix unified city names like ' Bangalore' → 'Bangalore'
--           and prevented silent undercounting of restaurants in affected cities.
--           Always run TRIM() as the very first cleaning step on any text column
--           that came from a CSV import or user input.


-- Q2. Standardize inconsistent cuisine labels
-- Issue: The cuisine column has multiple spellings for the same food type.
--        'North-Indian', 'north indian', and 'North Indian' are all different
--        strings in SQL but represent the same cuisine — causing GROUP BY
--        to split them into separate rows and undercount their true size.
-- Fix  : Normalize all variants to the canonical label 'North Indian'.
UPDATE restaurants
SET cuisine = 'North Indian'
WHERE LOWER(REPLACE(cuisine, '-', ' ')) LIKE '%north indian%';

-- Analysis: Inconsistent labels like 'North-Indian' cause GROUP BY to split
--           one cuisine into multiple rows, giving wrong counts and totals.
--           Standardizing to 'North Indian' ensures all 10,466 restaurants
--           are grouped correctly in every downstream query.


-- Q3. Handle NULL cuisine values
-- Issue: 4 rows have a NULL value in the cuisine column.
--        A NULL in GROUP BY creates a separate unnamed group and is excluded
--        from HAVING filters, leading to misleading aggregation results.
-- Fix  : Replace NULLs with 'Unknown' so every row is accounted for.
UPDATE restaurants
SET cuisine = 'Unknown'
WHERE cuisine IS NULL;

-- Analysis: While 4 rows is a small number (~0.006% of the dataset), building
--           the habit of replacing NULLs with a sentinel value like 'Unknown'
--           is critical in production pipelines. It prevents subtle GROUP BY
--           bugs and makes NULL-related issues visible in dashboards.


-- Q4. Remove extreme cost outliers
-- Issue: Several rows have a cost value of 1–49, which is not a realistic
--        price for a restaurant listed on Swiggy. These are almost certainly
--        data entry errors or test records that slipped into production data.
-- Fix  : Delete rows where cost < 50.
DELETE FROM restaurants
WHERE cost < 50;

-- Analysis: After deletion, 69 rows were removed (from 61,425 → 61,356).
--           The remaining cost range is ₹50–₹3,000, which aligns with
--           realistic Swiggy pricing. Keeping these outliers would drag down
--           city average cost calculations and distort the Budget segment size.


-- Q5. Flag unestablished restaurants using a derived column
-- Issue: Many restaurants have rating_count = 20, the platform minimum.
--        Including these in rating averages or revenue estimates inflates
--        noise because their ratings are based on near-zero real feedback.
-- Fix  : Add a boolean flag column is_established to mark restaurants
--        with rating_count > 50 as reliable data points.
ALTER TABLE restaurants ADD COLUMN is_established BOOLEAN;

UPDATE restaurants
SET is_established = CASE
    WHEN rating_count > 50 THEN TRUE
    ELSE FALSE
END;

-- Analysis: This flag can now be used as a WHERE filter in any downstream
--           query — for example, WHERE is_established = TRUE — to instantly
--           remove noisy low-review restaurants without rewriting logic each time.
--           It is far better practice than hardcoding rating_count > 50 in
--           every single query separately.


-- ============================================================================
-- SECTION 2 — EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================================

-- Q1. Dataset Overview — Scale of the market
-- Goal: Get a single-row snapshot of the dataset's total footprint.
--       This is always the very first query in any project to understand
--       the scale before drilling into any specific dimension.
SELECT
    COUNT(id)               AS total_restaurants,
    COUNT(DISTINCT city)    AS total_cities,
    COUNT(DISTINCT cuisine) AS total_cuisines
FROM restaurants;

-- Analysis: The dataset covers 61,356 restaurants across 534 cities and
--           108 distinct cuisines. The sheer number of cities (534) means
--           Swiggy has penetrated well beyond just metro India into Tier-2
--           and Tier-3 towns. This geographic spread makes city-level
--           segmentation a critical lens for all downstream analysis.


-- Q2. Top 5 Most Competitive Cities (Market Saturation)
-- Goal: Identify which cities have the highest restaurant density on Swiggy.
-- Insight: These are the most saturated markets. Entering them requires a
--          strong differentiator — not just being present is enough.
SELECT
    city,
    COUNT(id) AS restaurant_count
FROM restaurants
GROUP BY city
ORDER BY restaurant_count DESC
LIMIT 5;

-- Analysis:

--
-- Bangalore leads with 6,565 restaurants — the most competitive city in India.
-- Chennai (4,844) and Delhi (4,590) follow closely in 2nd and 3rd place.
-- Pune has the least competition among the top 5, making it a smarter
-- entry point for new brands compared to Bangalore or Chennai.


-- Q3. Average Cost for Two Across Major Metro Cities
-- Goal: Benchmark the average meal cost for two across the 7 largest metros.
-- Insight: Guides pricing strategy — a brand must price within the city's
--          norm to remain competitive, or justify a premium clearly.
SELECT
    city,
    ROUND(AVG(cost), 0) AS avg_cost_for_two,
    MIN(cost)           AS cheapest_option,
    MAX(cost)           AS most_expensive
FROM restaurants
WHERE city IN ('Bangalore', 'Delhi', 'Mumbai', 'Hyderabad', 'Pune', 'Chennai', 'Kolkata')
GROUP BY city
ORDER BY avg_cost_for_two DESC;

-- Analysis:

-- Mumbai is the most expensive city on average (₹403), nearly 28% higher
-- than Hyderabad (₹314). Notably, all cities share the same ₹50 minimum,
-- meaning budget options exist everywhere. A brand launching at ₹350–450
-- in Mumbai sits comfortably in the mid-range, whereas the same price
-- point would be considered above-average in Hyderabad or Chennai.


-- Q4. Rating Distribution — Quality Spread of the Market
-- Goal: Bucket all restaurants into rating bands to understand what
--       proportion of the market is high-quality vs mediocre.
SELECT
    CASE
        WHEN rating >= 4.5              THEN 'Excellent (4.5–5.0)'
        WHEN rating BETWEEN 4.0 AND 4.4 THEN 'Good (4.0–4.4)'
        WHEN rating BETWEEN 3.5 AND 3.9 THEN 'Average (3.5–3.9)'
        ELSE                                 'Below Average (<3.5)'
    END AS rating_band,
    COUNT(id)                                                        AS restaurant_count,
    ROUND(COUNT(id) * 100.0 / (SELECT COUNT(*) FROM restaurants), 1) AS pct_share
FROM restaurants
GROUP BY 1
ORDER BY restaurant_count DESC;

-- Analysis:


-- Nearly 44% of all restaurants land in the 'Good' band (4.0–4.4), which
-- means competition is intensely concentrated in that range. Only 7.3%
-- achieve an 'Excellent' rating — these are the true market leaders.
-- A new brand should target 4.3+ as the entry point to stand out,
-- since reaching 4.5+ is a rare achievement requiring exceptional quality.


-- Q5. Cuisine Variety per City
-- Goal: Find which cities offer the broadest range of food options.
-- Insight: Cities with high cuisine variety are cosmopolitan markets —
--          ideal for launching niche or international food concepts.
SELECT
    city,
    COUNT(DISTINCT cuisine) AS cuisine_variety,
    COUNT(id)               AS total_restaurants
FROM restaurants
GROUP BY city
ORDER BY cuisine_variety DESC
LIMIT 10;


--
-- Bangalore leads in cuisine diversity (79 types) — a reflection of its
-- large expat and tech-worker population willing to experiment with food.
-- Even Bikaner, a Tier-2 city, offers 51 cuisine types — suggesting that
-- diverse food demand is not exclusive to metros. This is a critical signal
-- for brands with niche or international menus planning city expansion.


-- ============================================================================
-- SECTION 3 — DEEP DIVE: CUISINE & POPULARITY
-- ============================================================================

-- Q1. Top 5 Cuisines by Total Demand (Rating Count Volume)
-- Goal: Determine which cuisines receive the highest total customer engagement
--       across all restaurants — a strong proxy for market-wide demand.
SELECT
    cuisine,
    COUNT(id)         AS restaurant_count,
    SUM(rating_count) AS total_votes
FROM restaurants
GROUP BY cuisine
ORDER BY total_votes DESC
LIMIT 5;

-- Analysis:

-- North Indian dominates by both supply (10,466) and demand (1.56M votes).
-- Most interesting is Biryani — it has less than half the restaurants of
-- North Indian, yet captures 67% of North Indian's total vote volume.
-- This means Biryani generates ~2.3x more votes per restaurant than
-- North Indian does — a powerful signal of per-outlet demand efficiency.


-- Q2. Highest Rated Cuisines (Statistically Significant — >5,000 Total Votes)
-- Goal: Find cuisine categories that consistently deliver quality to customers.
-- Logic: Any cuisine can average 4.5 if only 10 restaurants offer it.
--        We enforce a minimum of 5,000 total votes to ensure statistical
--        reliability before drawing conclusions from average ratings.
SELECT
    cuisine,
    ROUND(AVG(rating), 2) 
    AS avg_rating,
    SUM(rating_count)     
    AS total_votes,
    COUNT(id)             
    AS restaurant_count
FROM restaurants
GROUP BY cuisine
HAVING SUM(rating_count) > 5000
ORDER BY avg_rating DESC
LIMIT 5;

-- Analysis:

--
-- Ice Cream tops the quality chart at 4.29 average rating with 204K votes —
-- a very large, highly satisfied customer base. Desserts (4.12) and Burgers
-- (4.13) are also top performers. Notably, these are all snack/indulgence
-- categories — customers tend to be more forgiving and happy when ordering
-- treats, which may explain the consistently higher ratings. A new dessert
-- or ice cream brand starts with a naturally favorable customer sentiment.


-- Q3. Most Premium Cuisines by Average Cost
-- Goal: Rank cuisines by their average cost to identify luxury vs budget segments.
-- Insight: Useful for choosing what cuisine to offer based on the target
--          customer's spending capacity in a specific city.
SELECT
    cuisine,
    ROUND(AVG(cost), 0) AS avg_cost,
    COUNT(id)           AS restaurant_count
FROM restaurants
GROUP BY cuisine
HAVING COUNT(id) > 50
ORDER BY avg_cost DESC
LIMIT 5;

-- Analysis:

-- Japanese cuisine commands the highest average cost at ₹978 — nearly 3x
-- the overall dataset average. Despite this premium price, there are only
-- 65 Japanese restaurants, indicating low competition. A high-quality
-- Japanese brand in a city like Bangalore or Mumbai, where customers
-- already spend more, is a compelling premium market opportunity.


-- Q4. Underdog Cuisines — High Rating, Low Restaurant Count
-- Goal: Find cuisines that customers love but are underserved by supply.
-- Logic: We look for cuisines with fewer than 200 restaurants (low supply),
--        an average rating ≥ 4.0 (proven quality), and >3,000 total votes
--        (real demand exists, not just a niche hobby audience).
SELECT
    cuisine,
    COUNT(id)              AS restaurant_count,
    ROUND(AVG(rating), 2)  AS avg_rating,
    SUM(rating_count)      AS total_votes
FROM restaurants
GROUP BY cuisine
HAVING COUNT(id) < 200
   AND AVG(rating) >= 4.0
   AND SUM(rating_count) > 3000
ORDER BY avg_rating DESC
LIMIT 5;

-- Analysis:

--
-- Home Food is the most striking finding here — 157 restaurants, 4.09
-- average rating, and 49,080 votes. Demand is real and satisfaction is high,
-- but supply is thin. This is the clearest white-space opportunity in the
-- dataset. Mexican (39K votes, 4.06 rating) and Salads (29.6K votes) also
-- show that health-conscious urban dining is underserved relative to demand.


-- Q5. Revenue Proxy Ranking by Cuisine
-- Goal: Estimate the revenue potential of each cuisine using the formula:
--       revenue_proxy = rating_count × cost
-- Insight: A cuisine may be very popular but cheap (low revenue), or
--          expensive but niche (low volume). This metric captures BOTH
--          dimensions together to find the truly lucrative segments.
SELECT
    cuisine,
    SUM(rating_count * cost) AS estimated_revenue,
    ROUND(AVG(cost), 0)      AS avg_cost,
    SUM(rating_count)        AS total_orders_proxy
FROM restaurants
GROUP BY cuisine
ORDER BY estimated_revenue DESC
LIMIT 5;

-- Analysis:

--
-- North Indian leads with ₹486M estimated revenue — 30% higher than Biryani
-- (₹373M). However, Biryani earns this with 56% fewer restaurants, making
-- each Biryani outlet significantly more productive per unit. South Indian
-- earns nearly the same as Chinese (₹232M vs ₹233M) despite having fewer
-- votes — because its average cost (₹248) is lower than Chinese (₹307).
-- This shows that volume efficiency can compensate for price differences.


-- ============================================================================
-- SECTION 4 — ADVANCED ANALYTICS (Window Functions & CTEs)
-- ============================================================================

-- Q1. Top Rated Restaurant per City
-- Goal: Find the single best restaurant in each city based on rating,
--       using rating_count as a tiebreaker for statistically valid results.
-- Technique: RANK() partitioned by city. Using RANK() instead of ROW_NUMBER()
--            ensures that genuine ties (two restaurants with identical rating
--            AND rating_count) are both captured, not arbitrarily dropped.
WITH RankedByCity AS (
    SELECT
        name,
        city,
        cuisine,
        rating,
        rating_count,
        RANK() OVER (
            PARTITION BY city
            ORDER BY rating DESC, rating_count DESC
        ) AS city_rank
    FROM restaurants
    WHERE rating_count > 100
)
SELECT name, city, cuisine, rating, rating_count
FROM RankedByCity
WHERE city_rank = 1
ORDER BY city;

-- Analysis: By filtering WHERE rating_count > 100 before ranking, we ensure
--           that the "top restaurant" title is earned from a meaningful sample
--           of real customers — not gamed by a single restaurant with 3 five-star
--           reviews. The RANK() approach also handles cities where two restaurants
--           share the top spot, surfacing both rather than silently hiding one.
--           Key winners include Zaitoon (Chennai), Meghana Foods (Bangalore),
--           and Truffles (Bangalore) — consistently dominant brands.


-- Q2. Cumulative Revenue Snapshot per City
-- Goal: For Bangalore, Delhi, and Mumbai — show each restaurant alongside
--       a running cumulative revenue total, sorted by cost (descending).
-- Technique: SUM() as a window aggregate with ROWS BETWEEN UNBOUNDED PRECEDING
--            AND CURRENT ROW to build a running total within each city partition.
SELECT
    city,
    name,
    cost,
    rating_count,
    (rating_count * cost)                            AS restaurant_revenue,
    SUM(rating_count * cost) OVER (
        PARTITION BY city
        ORDER BY cost DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                AS cumulative_city_revenue
FROM restaurants
WHERE city IN ('Bangalore', 'Delhi', 'Mumbai')
ORDER BY city, cost DESC;

-- Analysis: This running total reveals how quickly each city accumulates its
--           total revenue and which price tier carries the most weight.
--           In Mumbai, the premium-cost restaurants (₹800+) contribute
--           disproportionately early to the cumulative total — confirming
--           that despite their smaller count, high-cost outlets drive
--           significant revenue. This insight validates targeting premium
--           positioning in Mumbai specifically.


-- Q3. Percentile Rank of Each Restaurant within Its Own City
-- Goal: Score every restaurant from 0 to 1 showing where it stands relative
--       to all other restaurants in the same city, based on rating + vote count.
-- Technique: PERCENT_RANK() — a score of 0.90 means the restaurant outperforms
--            90% of all restaurants in its city. This is far more meaningful
--            than raw rating alone, as it accounts for local context.
SELECT
    name,
    city,
    rating,
    rating_count,
    ROUND(
        PERCENT_RANK() OVER (PARTITION BY city ORDER BY rating, rating_count),
    2) AS percentile_in_city
FROM restaurants
WHERE city IN ('Bangalore', 'Chennai', 'Hyderabad')
ORDER BY city, percentile_in_city DESC;

-- Analysis: A restaurant with a 4.2 rating in Bangalore might only be in the
--           70th percentile because competition is so dense, while the same 4.2
--           in a smaller city could be in the 95th percentile. PERCENT_RANK()
--           normalizes for this local competitive intensity. This metric is
--           ideal for generating a "City Leaderboard" product feature, or for
--           identifying which restaurants are punching above their weight locally.


-- Q4. Top 3 Revenue-Generating Cuisines per City
-- Goal: For every city, rank cuisines by their estimated total revenue and
--       surface the top 3 — to understand each city's most lucrative food category.
-- Technique: DENSE_RANK() inside a CTE. Unlike RANK(), DENSE_RANK() does not
--            skip numbers after a tie — so if cuisines rank 1, 1, 2, not 1, 1, 3.
WITH CuisineCityRevenue AS (
    SELECT
        city,
        cuisine,
        SUM(rating_count * cost)   AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY city
            ORDER BY SUM(rating_count * cost) DESC
        )                          AS revenue_rank
    FROM restaurants
    GROUP BY city, cuisine
)
SELECT city, cuisine, total_revenue, revenue_rank
FROM CuisineCityRevenue
WHERE revenue_rank <= 3
ORDER BY city, revenue_rank;

-- Analysis: Across nearly every major city, North Indian consistently claims
--           either Rank 1 or Rank 2 by revenue — confirming its nationwide
--           dominance. Biryani frequently appears in the top 3 even in
--           South Indian-heavy cities like Chennai and Hyderabad, showing that
--           its appeal transcends regional preference. This query is directly
--           useful for city managers deciding where to invest in platform
--           promotions or new restaurant recruitment drives.


-- Q5. Detect Overpriced Restaurants vs Their City Average
-- Goal: Flag restaurants that charge more than 1.5× their city's average cost.
--       These are either genuine premium brands or potential pricing anomalies.
-- Technique: CTE to compute city-level average, then JOIN back to the main table
--            and filter with a ratio condition. The ratio column makes it easy
--            to sort by "how much more expensive" they are.
WITH CityAvgCost AS (
    SELECT
        city,
        AVG(cost) AS avg_city_cost
    FROM restaurants
    GROUP BY city
)
SELECT
    r.name,
    r.city,
    r.cuisine,
    r.cost,
    ROUND(c.avg_city_cost, 0) AS city_avg_cost,
    ROUND(r.cost / c.avg_city_cost, 2) AS cost_ratio
FROM restaurants r
JOIN CityAvgCost c ON r.city = c.city
WHERE r.cost > 1.5 * c.avg_city_cost
ORDER BY cost_ratio DESC
LIMIT 10;

-- Analysis: Restaurants appearing here with a cost_ratio of 2.0+ are charging
--           double their city's norm. In cities like Hyderabad or Chennai where
--           avg cost is ₹314–315, a restaurant priced at ₹700+ stands out sharply.
--           If these restaurants also carry high ratings and strong vote counts,
--           they are proven premium brands worth studying. If they carry low
--           ratings, they are likely overpriced and underdelivering — a red flag
--           for the platform to investigate or delist.


-- ============================================================================
-- SECTION 5 — BUSINESS INTELLIGENCE & STRATEGY
-- ============================================================================

-- Q1. Blue Ocean Strategy — High Demand, Low Supply (City + Cuisine Combos)
-- Goal: Find the best city–cuisine combinations to open a new restaurant.
--       The ideal opportunity has high customer demand (many votes) but
--       low current supply (few restaurants) — the classic 'Blue Ocean'.
-- Logic: supply < 30 restaurants and demand > 10,000 total votes.
SELECT
    city,
    cuisine,
    COUNT(id)             AS supply_count,
    SUM(rating_count)     AS demand_volume,
    ROUND(AVG(rating), 2) AS avg_rating
FROM restaurants
GROUP BY city, cuisine
HAVING COUNT(id) < 30
   AND SUM(rating_count) > 10000
ORDER BY demand_volume DESC
LIMIT 5;

-- Analysis:

--
-- The clearest opportunity is Burgers in Chennai — 14,570 demand votes but
-- only 29 restaurants, AND a 4.16 average rating meaning existing outlets
-- are already delighting customers. This is a ready, proven market that is
-- simply underserved. Hyderabad's Home Food gap (19 restaurants, 10,270 votes,
-- 4.07 rating) is equally compelling — the work-from-home culture has
-- created strong demand for homestyle meals that platforms have not yet met.


-- Q2. Price Segment Strategy — Market Distribution & Performance
-- Goal: Understand how the market is split across Budget, Mid-range, and
--       Premium tiers, and which tier earns the best customer satisfaction.
-- Insight: Helps decide the right price positioning before launch.
SELECT
    CASE
        WHEN cost < 300               THEN 'Budget (<₹300)'
        WHEN cost BETWEEN 300 AND 600 THEN 'Mid-range (₹300–₹600)'
        ELSE                               'Premium (>₹600)'
    END AS price_segment,
    COUNT(id)             AS total_restaurants,
    ROUND(AVG(rating), 2) AS avg_rating,
    SUM(rating_count)     AS total_votes,
    ROUND(AVG(cost), 0)   AS avg_cost
FROM restaurants
GROUP BY 1
ORDER BY total_restaurants DESC;

-- Analysis:


-- Budget restaurants dominate supply (54% of all restaurants) but earn the
-- lowest ratings (3.85) and are outvoted by Mid-range despite having more
-- outlets. Premium restaurants, though only 3.7% of supply, average a 4.16
-- rating — the highest of all three tiers. The data strongly suggests that
-- premium restaurants deliver consistently better experiences. A brand launching
-- in the ₹600–₹1,000 range faces far less competition (2,266 restaurants)
-- while serving a more satisfied and loyal customer base.


-- Q3. Brand Expansion Radar — Underpenetrated Cities with High Satisfaction
-- Goal: Find cities where the customer base is already happy with existing
--       restaurants but the total supply is still relatively small.
-- Logic: These cities have a quality-hungry audience but limited options —
--        making them the lowest-risk, highest-upside expansion targets.
SELECT
    city,
    COUNT(id)              AS restaurant_count,
    ROUND(AVG(rating), 2)  AS avg_rating,
    ROUND(AVG(cost), 0)    AS avg_cost
FROM restaurants
GROUP BY city
HAVING COUNT(id) BETWEEN 10 AND 100
   AND AVG(rating) >= 4.0
ORDER BY avg_rating DESC
LIMIT 10;

-- Analysis:

-- South Goa is particularly interesting — a small market (12 restaurants),
-- a 4.17 average rating (customers love what exists), and an avg cost of ₹408
-- (mid-range, not budget). This is a tourist-heavy, quality-conscious market
-- that is nearly completely untapped on Swiggy. Lonavala follows the same
-- pattern — weekend-destination cities with affluent visitors but minimal
-- delivery infrastructure, presenting a genuine first-mover advantage.


-- Q4. Customer Loyalty Leaders — High Rating AND High Review Volume
-- Goal: Identify the restaurants that have earned both mass popularity
--       and high quality simultaneously — the true power brands on the platform.
-- Logic: rating >= 4.3 (top quality tier) AND rating_count >= 1,000
--        (enough volume to be statistically meaningful).
SELECT
    name,
    city,
    cuisine,
    rating,
    rating_count,
    (rating_count * cost) AS revenue_proxy
FROM restaurants
WHERE rating >= 4.3
  AND rating_count >= 1000
ORDER BY revenue_proxy DESC
LIMIT 10;

-- Analysis:


-- Zaitoon in Chennai leads by a wide margin at ₹4.5M revenue proxy — twice
-- the nearest competitor. It appears multiple times in the dataset across
-- different Chennai branches, confirming it is a dominant chain with a
-- proven formula. Meghana Foods (Bangalore) and Truffles (Bangalore) are
-- the strongest performers in the most competitive market — a testament to
-- truly exceptional product-market fit. These brands are ideal benchmarks
-- for studying what operational excellence looks like on Swiggy.


-- Q5. Competitive Threat Index — Cities Dominated by One Cuisine
-- Goal: Detect city–cuisine combinations where a single cuisine controls
--       more than 40% of all restaurant listings in that city.
-- Insight: These cities are risky entry points for brands IN that dominant
--          cuisine — but represent a clear gap for ALL OTHER cuisines.
WITH CityTotal AS (
    SELECT city, COUNT(id) AS total_in_city
    FROM restaurants
    GROUP BY city
),
CuisineShare AS (
    SELECT
        r.city,
        r.cuisine,
        COUNT(r.id)                                            AS cuisine_count,
        ct.total_in_city,
        ROUND(COUNT(r.id) * 100.0 / ct.total_in_city, 1)     AS market_share_pct
    FROM restaurants r
    JOIN CityTotal ct ON r.city = ct.city
    GROUP BY r.city, r.cuisine, ct.total_in_city
)
SELECT city, cuisine, cuisine_count, total_in_city, market_share_pct
FROM CuisineShare
WHERE market_share_pct > 40
  AND total_in_city > 50
ORDER BY market_share_pct DESC
LIMIT 10;

-- Analysis:


-- North Indian cuisine dominates almost every Tier-2 city it appears in,
-- in some cases controlling nearly half of all restaurant slots. For a brand
-- looking to launch North Indian in Karnal or Rewa, this is a warning — the
-- market is already saturated. However, it is a green light for ANY other
-- cuisine: in Karnal, where 48.6% of restaurants are North Indian, there is
-- almost no representation of Burgers, Desserts, or Healthy Food — meaning
-- the remaining 51.4% of supply is split among dozens of other categories.
-- Rourkela is a unique case where Chinese dominates (43.9%) — not North Indian
-- — suggesting a strong regional preference that aligns with East Indian
-- cultural ties to Chinese-influenced cuisine.


/*
===============================================================================
END OF PROJECT — Strategic Summary of Key Findings

DATA CLEANING
  - City whitespace and cuisine NULLs were fixed before any analysis began.
  - 69 rows with cost < ₹50 removed as data entry noise.
  - is_established flag added for use as a reusable quality filter.

EDA
  - Bangalore is the most saturated market (6,565 restaurants).
  - Mumbai has the highest average dining cost (₹403 for two).
  - Only 7.3% of restaurants achieve an Excellent (4.5+) rating.

CUISINE INSIGHTS
  - Biryani generates 2.3x more votes per restaurant than North Indian.
  - Ice Cream and Desserts lead quality ratings among established cuisines.
  - Home Food, Mexican, and Japanese are the top underserved cuisines by demand.

ADVANCED ANALYTICS
  - Zaitoon (Chennai) and Meghana Foods (Bangalore) are the platform's top earners.
  - Premium restaurants (>₹600) earn the highest avg rating (4.16) despite being
    only 3.7% of supply — a strong case for premium positioning.

STRATEGIC RECOMMENDATIONS
  1. Launch: Burgers in Chennai — proven demand (14,570 votes), only 29 competitors.
  2. Expansion: South Goa and Lonavala — high avg ratings, minimal supply.
  3. Avoid: North Indian in Karnal, Rewa, Jammu — market share already 45–48%.
  4. Premium Play: A Japanese brand in Bangalore or Mumbai can charge ₹978 avg
     with very little competition (only 65 restaurants nationwide).
===============================================================================
*/
