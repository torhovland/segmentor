type Environment = "Development" | "Production";

export function useEnvironment(): Environment {
    return window.location.hostname === "localhost" ? "Development" : "Production";
}

export function useBaseName(): string {
    return useEnvironment() === "Development" ? "localhost:8088" : "segmentor.hovland.xyz";
}