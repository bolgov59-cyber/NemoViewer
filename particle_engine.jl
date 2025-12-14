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
        # Используем последнюю доступную дату
        # Берём максимальную дату из БД
        result = LibPQ.execute(conn, "SELECT MAX(dat) as latest_date FROM _nemo")
        latest_date = first(result).latest_date
#        latest_date = Date(DatabaseFunctions.get_latest_date())
        partition_schema = Dates.format(latest_date, "yyyy-mm-dd")
        table_name = "_nemo_$(partition_schema)"
        
        # Случайные точки ВСЕЙ сетки
        query = """
        SELECT 
            ST_X(geom) as lon,
            ST_Y(geom) as lat
        FROM "$(partition_schema)"."$(table_name)"
        WHERE dat = \$1
          AND (par->0->>'depth')::float = \$2  -- ← ТОЧНОЕ СОВПАДЕНИЕ
        ORDER BY RANDOM()
        LIMIT \$3
        """
        println(query)
        
        result = LibPQ.execute(conn, query, [latest_date, count])
        
        particles = [(lon=row.lon, lat=row.lat) for row in result]
        println("🎯 Сгенерировано $(length(particles)) частиц по всему океану")
        
        return particles
        
    catch e
        println("❌ Ошибка в generate_particle_seeds: ", e)
        return []
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
