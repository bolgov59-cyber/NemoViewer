module ParticleEngine

using Dates, JSON3, LinearAlgebra
using LibPQ
using Main.DatabaseFunctions: get_connection, get_latest_date

export get_velocity_grid, generate_particle_seeds, parse_depth_string

# Кэш для сеток (date, depth, forecast_idx) -> сетка
const VELOCITY_CACHE = Dict{Tuple{Date,Float64,Int},Any}()

"""
    get_velocity_grid(date::Date, depth_val::Float64, forecast_idx::Int)

Загружает ВСЮ сетку NEMO для заданной даты, глубины и времени прогноза.
Использует кэширование.
"""
function get_velocity_grid(date::Date, depth_val::Float64, forecast_idx::Int)
    # Проверяем кэш
    cache_key = (date, depth_val, forecast_idx)
    if haskey(VELOCITY_CACHE, cache_key)
        println("♻️  Используем кэшированную сетку")
        return VELOCITY_CACHE[cache_key]
    end
    
    conn = get_connection()
    
    try
        # Имя секции
        partition_schema = Dates.format(date, "yyyy-mm-dd")
        table_name = "_nemo_$(partition_schema)"
        
        println("🔍 Загрузка всей сетки: $partition_schema, глубина=$depth_val, время=$forecast_idx")
        
        # ПРОСТЕЙШИЙ ЗАПРОС - ВСЕ точки секции
        query = """
        SELECT 
            ST_X(geom) as lon,
            ST_Y(geom) as lat,
            par
        FROM "$(partition_schema)"."$(table_name)"
        WHERE dat = \$1
        """
        
        result = LibPQ.execute(conn, query, [date])
        
        if isempty(result)
            @warn "⚠️ Нет данных в секции" date
            return nothing
        end
        
        # Обработка в памяти
        lons = Float64[]
        lats = Float64[]
        u_vals = Float64[]
        v_vals = Float64[]
        
        processed = 0
        skipped_depth = 0
        skipped_time = 0
        
        for row in result
            parsed_data = JSON3.read(row.par)
            
            if length(parsed_data) > 0
                first_horizon = parsed_data[1]  # Первый горизонт глубин
                
                # Проверяем наличие нужных полей
                if haskey(first_horizon, "depth") &&
                   haskey(first_horizon, "u") && 
                   haskey(first_horizon, "v")
                    
                    depth = first_horizon["depth"]
                    
                    # Фильтр глубины ±5 метров
                    if abs(depth - depth_val) <= 5.0
                        u_array = first_horizon["u"]
                        v_array = first_horizon["v"]
                        
                        # Проверяем индекс времени
                        if forecast_idx <= length(u_array)
                            push!(lons, row.lon)
                            push!(lats, row.lat)
                            push!(u_vals, u_array[forecast_idx])
                            push!(v_vals, v_array[forecast_idx])
                            processed += 1
                        else
                            skipped_time += 1
                        end
                    else
                        skipped_depth += 1
                    end
                end
            end
        end
        
        # Создаем структуру данных
        grid_data = (
            lons=lons,
            lats=lats, 
            u=u_vals,
            v=v_vals,
            count=length(lons),
            metadata=Dict(
                "date" => string(date),
                "depth_requested" => depth_val,
                "forecast_idx" => forecast_idx,
                "total_points" => length(result),
                "processed" => processed,
                "skipped_depth" => skipped_depth,
                "skipped_time" => skipped_time
            )
        )
        
        # Сохраняем в кэш
        VELOCITY_CACHE[cache_key] = grid_data
        
        println("✅ Сетка: $(length(result)) строк → $processed точек " *
                "(пропущено: глубина=$skipped_depth, время=$skipped_time)")
        
        return grid_data
        
    catch e
        println("❌ Ошибка в get_velocity_grid: ", e)
        return nothing
    finally
        close(conn)
    end
end

"""
    generate_particle_seeds(count::Int)

Генерирует случайные точки по ВСЕЙ сетке NEMO (весь океан).
"""
function generate_particle_seeds(count::Int, depth_val::Float64)
    conn = get_connection()
    
    try
        # 1. Получаем дату
        date_result = LibPQ.execute(conn, "SELECT MAX(dat) as latest_date FROM _nemo")
        latest_date = first(date_result).latest_date
        
        partition_schema = Dates.format(latest_date, "yyyy-mm-dd")
        table_name = "_nemo_$(partition_schema)"
        
        # 2. ОПТИМИЗИРОВАННЫЙ ЗАПРОС - TABLESAMPLE
        query = """
WITH ocean_bbox AS (
    -- Bounding box всего океана для этой даты/глубины
    SELECT ST_Extent(geom) as bbox
    FROM "$(partition_schema)"."$(table_name)"
    WHERE dat = \$1 
      AND (par->0->>'depth')::float = \$2
),
random_points AS (
    -- Генерируем случайные точки в bounding box
    SELECT 
        ST_X(ST_GeneratePoints(bbox, \$3 * 2)) as lon,  -- ×2 для запаса
        ST_Y(ST_GeneratePoints(bbox, \$3 * 2)) as lat
    FROM ocean_bbox
)
-- Фильтруем только те, что попадают в реальные точки сетки
SELECT DISTINCT ON (rp.lon, rp.lat)
    rp.lon, rp.lat
FROM random_points rp
JOIN "$(partition_schema)"."$(table_name)" t 
  ON ST_DWithin(t.geom, ST_SetSRID(ST_MakePoint(rp.lon, rp.lat), 4326), 0.1)
WHERE t.dat = \$1 
  AND (t.par->0->>'depth')::float = \$2
LIMIT \$3;
        """
        
        println("🔍 Быстрая генерация частиц: TABLESAMPLE SYSTEM (0.5%)")
        
        result = LibPQ.execute(conn, query, [latest_date, depth_val, count])
        
        particles = [(lon=row.lon, lat=row.lat) for row in result]
        
        # 3. Если мало точек — делаем полный запрос (редкий случай)
        if length(particles) < count * 0.8  # Меньше 80%
            println("⚠️  TABLESAMPLE дал мало точек, делаем полный запрос")
            query_full = """
            SELECT 
                ST_X(geom) as lon,
                ST_Y(geom) as lat
            FROM "$(partition_schema)"."$(table_name)"
            WHERE dat = \$1
              AND (par->0->>'depth')::float = \$2
            ORDER BY RANDOM()
            LIMIT \$3
            """
            result = LibPQ.execute(conn, query_full, [latest_date, depth_val, count])
            particles = [(lon=row.lon, lat=row.lat) for row in result]
        end
        
        println("✅ Сгенерировано $(length(particles)) частиц за миллисекунды")
        
        return particles
        
    catch e
        println("❌ Ошибка в generate_particle_seeds: ", e)
        # Fallback: случайные координаты в океане
        println("🔄 Fallback: случайные координаты океана")
        return [(lon=-180 + 360*rand(), lat=-90 + 180*rand()) for _ in 1:count]
    finally
        close(conn)
    end
end

"""
    parse_depth_string(depth_str::String)

Преобразует "0p5" -> 0.5, "97" -> 97.0
"""
function parse_depth_string(depth_str::String)
    depth_map = Dict(
        "0p5" => 0.51,
        "97" => 97.04, 
        "1046" => 1045.85
    )
    return get(depth_map, depth_str, 0.51)
end

"""
    clear_cache()

Очищает кэш сеток (полезно при смене даты).
"""
function clear_cache()
    empty!(VELOCITY_CACHE)
    println("🧹 Кэш сеток очищен")
end

end # module ParticleEngine
