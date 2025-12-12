# Упрощенный particle_routes.jl
using Genie.Router, Genie.Renderer.Json
using Dates, JSON
include("../../src/models/particle_tracer.jl")
using .ParticleTracer

# Регистрируем маршруты сразу (без функции)
route("/api/particles/trajectories", method=GET) do
    try
        date = Date(params(:date, "2024-01-15"))
        depth_index = parse(Int, params(:depth_index, "0"))
        forecast_range = parse(Int, params(:forecast_range, "240"))
        region = params(:region, "wo")
        particle_count = parse(Int, params(:particle_count, "1000"))
        
        trajectories = ParticleTracer.calculate_particle_trajectories(
            date, depth_index, forecast_range, region,
            particle_count=min(particle_count, 5000)
        )
        
        return Json.json(Dict(
            "success" => true,
            "date" => string(date),
            "depth_index" => depth_index,
            "forecast_range" => forecast_range,
            "region" => region,
            "particle_count" => length(trajectories),
            "trajectories" => trajectories
        ))
        
    catch e
        @error "Ошибка в particles/trajectories" exception=e
        return Json.json(Dict(
            "success" => false,
            "error" => "Ошибка сервера: $(string(e))"
        ))
    end
end

# Тестовый маршрут
route("/api/particles/test", method=GET) do
    return Json.json(Dict("message" => "Particles API работает!"))
end

println("✅ Маршруты частиц зарегистрированы")
