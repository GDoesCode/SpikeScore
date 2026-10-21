namespace SpikeScore.Web.Models;

public record MatchEvent(string Type, string Team, int PlayerOff = 0, int PlayerOn = 0);