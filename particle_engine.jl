# src/utils/particle_engine.jl
module ParticleEngine

using Dates, JSON3, LinearAlgebra
using LibPQ
using ..DatabaseFunctions: get_connection

export get_velocity_field, generate_particle_seeds, parse_depth_string

"""
    get_velocity_field(date::Date, depth::Float64, forecast_hour::Int, bbox)

Оптимизированный PostGIS-запрос. Возвращает (lons, lats, u, v) для области bbox.
"""
function get_velocity_field(date::Date, depth_val::Float64, forecast_hour::Int,
                           bbox::Union{Nothing, Tuple{Float64,Float64,Float64,Float64}}=nothing)
    conn = get_connection()
    try
        # 1. Определяем область запроса
        bbox_geom = if bbox !== nothing
            "ST_MakeEnvelope($(bbox[1]), $(bbox[2]), $(bbox[3]), $(bbox[4]), 4326)"
        else
            "ST_MakeEnvelope(-180, -90, 180, 90, 4326)"  # Весь мир
        end

        # 2. Индекс во временном массиве (0,1,...,10)
        forecast_idx = forecast_hour ÷ 24

        # 3. ОСНОВНОЙ POSTGIS-ЗАПРОС (использует пространственный индекс)
        query = """
        SELECT lon, lat,
               (par->\$3->>'u')::float as u,
               (par->\$3->>'v')::float as v
        FROM _nemo
        WHERE dat = \$1
          AND ST_Within(geom, $bbox_geom)
          AND (par->0->>'depth')::float BETWEEN \$2 - 5 AND \$2 + 5
          AND jsonb_array_length(par) > \$3
        ORDER BY lat DESC, lon ASC
        """

        result = LibPQ.execute(conn, query, [date, depth_val, forecast_idx])

        if isempty(result)
            @warn "Нет данных скорости" date depth_val forecast_idx
            return nothing
        end

        # 4. Преобразуем в массивы
        lons = Float64[r.lon for r in result]
        lats = Float64[r.lat for r in result]
        u = Float64[r.u for r in result]
        v = Float64[r.v for r in result]

        return (lons=lons, lats=lats, u=u, v=v, count=length(lons))

    finally
        close(conn)
    end
end

"""
    generate_particle_seeds(region::String, count::Int, bbox)

Генерирует случайные точки в океане с помощью PostGIS.
"""
function generate_particle_seeds(region::String, count::Int,
                                bbox::Union{Nothing, Tuple{Float64,Float64,Float64,Float64}}=nothing)
    conn = get_connection()
    try
        # Используем последнюю доступную дату как маску океана
        latest_date = Date(DatabaseFunctions.get_latest_date())

        bbox_clause = if bbox !== nothing
            "AND ST_Within(geom, ST_MakeEnvelope($(bbox[1]), $(bbox[2]), $(bbox[3]), $(bbox[4]), 4326))"
        else
            ""
        end

        query = """
        WITH ocean_points AS (
            SELECT lon, lat, geom
            FROM _nemo
            WHERE dat = \$1
              AND (par->0->>'depth')::float > 0  # Только вода
              $bbox_clause
            GROUP BY lon, lat, geom
        )
        SELECT lon, lat
        FROM ocean_points
        ORDER BY RANDOM()
        LIMIT \$2
        """

        result = LibPQ.execute(conn, query, [latest_date, count])

        return [(lon=row.lon, lat=row.lat) for row in result]

    finally
        close(conn)
    end
end

"""
    parse_depth_string(depth_str::String)

Преобразует "0p5" -> 0.5, "97" -> 97.0
"""
function parse_depth_string(depth_str::String)
    if endswith(depth_str, "p5")
        return parse(Float64, replace(depth_str, "p" => "."))
    else
        return parse(Float64, depth_str)
    end
end

end # module ParticleEngine
