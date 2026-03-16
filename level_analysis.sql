-- 1. Lấy thông tin (Max Date và Tổng số người chơi)
WITH global AS (
    SELECT 
        MAX(event_date) AS max_date,
        COUNT(DISTINCT user_pseudo_id) AS total_users 
    FROM `hm-games-test-da.dataset.level_start`
),

-- 2. Tìm Level drop của từng user và lọc ra những user thực sự drop
user_max_level AS (
    SELECT 
        user_pseudo_id, 
        MAX(level) AS drop_level,
        MAX(event_date) AS max_user_date
    FROM `hm-games-test-da.dataset.level_start`
    GROUP BY user_pseudo_id
),
drop_stats AS (
    SELECT 
        drop_level AS level,
        COUNT(DISTINCT user_pseudo_id) AS drop_users
    FROM user_max_level
    CROSS JOIN global
    WHERE max_user_date < (global.max_date - INTERVAL 1 DAY)
    GROUP BY drop_level
),

-- 3. Gom nhóm lượt Start theo từng Level
start_stats AS (
    SELECT 
        level,
        COUNT(DISTINCT user_pseudo_id) AS started_users
    FROM `hm-games-test-da.dataset.level_start`
    GROUP BY level
),

-- 4. Gom nhóm lượt End theo từng Level
end_stats AS (
    SELECT 
        level,
        COUNT(DISTINCT user_pseudo_id) AS completed_users
    FROM `hm-games-test-da.dataset.level_end`
    GROUP BY level
),

-- 5. Gom nhóm Doanh thu theo từng Level
revenue_stats AS (
    SELECT 
        level,
        SUM(revenue) AS total_revenue
    FROM `hm-games-test-da.dataset.revenue_ads`
    GROUP BY level
)

-- 6. JOIN các bảng đã gom nhóm lại với nhau
SELECT 
    s.level,
    s.started_users,
    COALESCE(e.completed_users, 0) AS completed_users,
    g.total_users,
    
    -- Sử dụng SAFE_DIVIDE thay vì phép chia để tránh lỗi chia cho 0
    ROUND(SAFE_DIVIDE(e.completed_users, s.started_users) * 100, 2) AS win_rate,
    ROUND(100 - SAFE_DIVIDE(e.completed_users, s.started_users) * 100, 2) AS loss_rate,
    
    ROUND(COALESCE(r.total_revenue, 0), 2) AS revenue,
    ROUND(SAFE_DIVIDE(r.total_revenue, s.started_users), 3) AS arpu,
    
    ROUND(SUM(r.total_revenue) OVER(ORDER BY s.level ASC), 2) AS cumulative_revenue,
    
    ROUND(SAFE_DIVIDE(SUM(r.total_revenue) OVER(ORDER BY s.level ASC), g.total_users), 2) AS cumulative_arpu,
    
    COALESCE(d.drop_users, 0) AS drop_users,

    ROUND(SAFE_DIVIDE(COALESCE(d.drop_users, 0), s.started_users) * 100, 2) AS drop_rate

FROM start_stats s
CROSS JOIN global g 
LEFT JOIN end_stats e 
    ON s.level = e.level
LEFT JOIN revenue_stats r 
    ON s.level = r.level
LEFT JOIN drop_stats d 
    ON s.level = d.level
ORDER BY s.level ASC
LIMIT 100;
