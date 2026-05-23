# 🍔 Swiggy Restaurant Data Analysis — SQL Project

A complete end-to-end SQL analysis of Swiggy's restaurant dataset to uncover market gaps, benchmark city pricing, identify top cuisines, and recommend data-driven expansion strategies.

---

## 📊 Dataset Overview

| Metric | Value |
|---|---|
| Total Restaurants | 61,356 |
| Cities Covered | 534 |
| Distinct Cuisines | 108 |
| DB Compatibility | MySQL / PostgreSQL |

---

## 📁 Project Structure

```
swiggy-sql-analysis/
├── sql_swiggy_project.sql   ← Full analysis (cleaning + queries)
└── README.md
```

---

## 🗂️ Sections Covered

### Section 1 — Data Cleaning & Standardization
- Trimmed leading/trailing whitespace from city names
- Standardized inconsistent cuisine labels (`North-Indian` → `North Indian`)
- Replaced NULL cuisine values with `'Unknown'`
- Removed 69 outlier rows with cost < ₹50
- Added `is_established` boolean flag for restaurants with `rating_count > 50`

### Section 2 — Exploratory Data Analysis (EDA)
- Dataset scale snapshot (restaurants, cities, cuisines)
- Top 5 most competitive cities by restaurant count
- Average cost benchmarking across 7 major metros
- Rating distribution across Excellent / Good / Average / Below Average bands
- Cuisine variety per city

### Section 3 — Cuisine & Popularity Deep Dive
- Top 5 cuisines by total demand (rating count volume)
- Highest rated cuisines (statistically filtered: >5,000 votes)
- Most premium cuisines by average cost
- Underdog cuisines — high rating, low supply
- Revenue proxy ranking by cuisine (`rating_count × cost`)

### Section 4 — Advanced Analytics (Window Functions & CTEs)
- Top rated restaurant per city using `RANK()`
- Cumulative revenue snapshot per city using `SUM() OVER`
- Percentile rank of each restaurant within its city using `PERCENT_RANK()`
- Top 3 revenue-generating cuisines per city using `DENSE_RANK()`
- Overpriced restaurant detection vs city average using CTE + JOIN

### Section 5 — Business Intelligence & Strategy
- Blue Ocean Strategy — high demand, low supply city–cuisine combos
- Price segment strategy — Budget / Mid-range / Premium performance
- Brand expansion radar — underpenetrated cities with high satisfaction
- Customer loyalty leaders — high rating AND high review volume
- Competitive threat index — cities dominated by one cuisine (>40% share)

---

## 🔑 Key Findings

- **Bangalore** is the most saturated market with 6,565 restaurants
- **Mumbai** has the highest average dining cost (₹403 for two)
- Only **7.3%** of restaurants achieve an Excellent rating (4.5+)
- **Biryani** generates 2.3× more votes per restaurant than North Indian
- **Home Food, Mexican, and Japanese** are the top underserved cuisines by demand
- **Zaitoon (Chennai)** leads revenue proxy at ₹4.5M — dominant chain across branches
- **Premium restaurants (>₹600)** earn the highest avg rating (4.16) despite being only 3.7% of supply

---

## 🚀 Strategic Recommendations

| # | Recommendation |
|---|---|
| 1 | **Launch** Burgers in Chennai — 14,570 demand votes, only 29 competitors |
| 2 | **Expand** to South Goa and Lonavala — high avg ratings, minimal supply |
| 3 | **Avoid** North Indian in Karnal, Rewa, Jammu — already 45–48% market share |
| 4 | **Premium Play** — Japanese brand in Bangalore/Mumbai, avg cost ₹978, only 65 restaurants nationwide |

---

## 🛠️ Tech Stack

- **SQL** — MySQL / PostgreSQL
- **Concepts Used** — Window Functions, CTEs, Subqueries, Aggregations, CASE statements, JOINs

---

## 👤 Author

**Yug Saxena**  
B.Tech IT | JSS Academy of Technical Education, Noida  
[GitHub](https://github.com/yugsaxena102)
