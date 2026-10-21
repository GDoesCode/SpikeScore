using Microsoft.JSInterop;
using SpikeScore.Web.Models;

namespace SpikeScore.Web.Services;

public class MatchEngine
{
    private readonly IJSRuntime _js;
    private const string StorageKey = "spike_score_active_match";

    public int HomeScore { get; private set; }
    public int AwayScore { get; private set; }
    public int HomeTimeOuts { get; private set; }
    public int AwayTimeOuts { get; private set; }
    public int HomeSubCount { get; private set; }
    public int AwaySubCount { get; private set; }

    private List<int> homeRoster = new() { 1, 3, 5, 7, 9, 11, 13, 15 };
    private List<int> homeOnCourt = new() { 1, 3, 5, 7, 9, 11 };

    private List<int> awayRoster = new() { 2, 4, 6, 8, 10, 12, 14, 16 };
    private List<int> awayOnCourt = new() { 2, 4, 6, 8, 10, 12 };

    private Dictionary<string, Dictionary<int, int>> teamSubPairs = new()
    {
        { "Home", new() },
        { "Away", new() }
    };

    private Stack<MatchEvent> eventHistory = new();
    public bool CanUndo => eventHistory.Count > 0;

    // UI Workflow State
    public bool IsTeamModalOpen { get; private set; }
    public bool IsSubModalOpen { get; private set; }
    public bool IsErrorModalOpen { get; private set; }

    public string ActiveAction { get; private set; } = "";
    public string ActiveTeam { get; private set; } = "";
    public string ErrorMessage { get; private set; } = "";

    public int SubStep { get; private set; } = 1;
    public int SelectedPlayerOff { get; private set; }

    public MatchEngine(IJSRuntime js)
    {
        _js = js;
        _ = LoadStateAsync();
    }

    private async Task SaveStateAsync()
    {
        try
        {
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_homeScore", HomeScore);
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_awayScore", AwayScore);
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_homeTO", HomeTimeOuts);
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_awayTO", AwayTimeOuts);
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_homeSubs", HomeSubCount);
            await _js.InvokeVoidAsync("localStorage.setItem", $"{StorageKey}_awaySubs", AwaySubCount);
        }
        catch { /* Ignore if JS runtime isn't ready */ }
    }

    public async Task LoadStateAsync()
    {
        try
        {
            var homeScoreStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_homeScore");
            if (int.TryParse(homeScoreStr, out var hScore)) HomeScore = hScore;

            var awayScoreStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_awayScore");
            if (int.TryParse(awayScoreStr, out var aScore)) AwayScore = aScore;

            var homeTOStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_homeTO");
            if (int.TryParse(homeTOStr, out var hTO)) HomeTimeOuts = hTO;

            var awayTOStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_awayTO");
            if (int.TryParse(awayTOStr, out var aTO)) AwayTimeOuts = aTO;

            var homeSubsStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_homeSubs");
            if (int.TryParse(homeSubsStr, out var hSubs)) HomeSubCount = hSubs;

            var awaySubsStr = await _js.InvokeAsync<string>("localStorage.getItem", $"{StorageKey}_awaySubs");
            if (int.TryParse(awaySubsStr, out var aSubs)) AwaySubCount = aSubs;
        }
        catch { /* Ignore on first boot */ }
    }

    public async void ScorePoint(string team)
    {
        if (team == "Home") HomeScore++;
        else AwayScore++;
        eventHistory.Push(new MatchEvent("Point", team));
        await SaveStateAsync();
    }

    public void OpenTeamModal(string actionType)
    {
        ActiveAction = actionType;
        IsTeamModalOpen = true;
    }

    public void CloseModals()
    {
        IsTeamModalOpen = false;
        IsSubModalOpen = false;
        SubStep = 1;
        SelectedPlayerOff = 0;
    }

    public void CloseErrorModal() => IsErrorModalOpen = false;

    public async void ConfirmTeam(string team)
    {
        ActiveTeam = team;
        IsTeamModalOpen = false;

        if (ActiveAction == "Timeout")
        {
            if (!TryTakeTimeout(team, out string err)) ShowError(err);
            else await SaveStateAsync();
        }
        else if (ActiveAction == "Sub")
        {
            if (!TryValidateSubstitution(team, out string err))
            {
                ShowError(err);
                return;
            }
            SubStep = 1;
            IsSubModalOpen = true;
        }
    }

    public async void SelectPlayerOff(int playerNum)
    {
        SelectedPlayerOff = playerNum;
        var benchPlayers = GetBenchPlayers(ActiveTeam, SelectedPlayerOff);
        if (benchPlayers.Count == 1)
        {
            ExecuteSubstitution(ActiveTeam, SelectedPlayerOff, benchPlayers[0]);
            CloseModals();
            await SaveStateAsync();
        }
        else
        {
            SubStep = 2;
        }
    }

    public async void SelectPlayerOn(int playerNum)
    {
        ExecuteSubstitution(ActiveTeam, SelectedPlayerOff, playerNum);
        CloseModals();
        await SaveStateAsync();
    }

    private bool TryTakeTimeout(string team, out string errorMessage)
    {
        errorMessage = string.Empty;
        int currentTOs = team == "Home" ? HomeTimeOuts : AwayTimeOuts;

        if (currentTOs >= 2)
        {
            errorMessage = $"Max time-outs used for {team.ToUpper()} (2/2).";
            return false;
        }

        if (team == "Home") HomeTimeOuts++;
        else AwayTimeOuts++;

        eventHistory.Push(new MatchEvent("Timeout", team));
        return true;
    }

    private bool TryValidateSubstitution(string team, out string errorMessage)
    {
        errorMessage = string.Empty;
        int subCount = team == "Home" ? HomeSubCount : AwaySubCount;

        if (subCount >= 6)
        {
            errorMessage = $"Max substitutions reached for {team.ToUpper()} (6/6).";
            return false;
        }
        return true;
    }

    public List<int> GetOnCourtPlayers(string team) => team == "Home" ? homeOnCourt : awayOnCourt;

    public List<int> GetBenchPlayers(string team, int selectedPlayerOff)
    {
        var roster = team == "Home" ? homeRoster : awayRoster;
        var onCourt = GetOnCourtPlayers(team);
        var subPairs = teamSubPairs[team];

        if (subPairs.TryGetValue(selectedPlayerOff, out int originalPartner))
        {
            if (!onCourt.Contains(originalPartner))
            {
                return new List<int> { originalPartner };
            }
        }

        return roster.Where(p => !onCourt.Contains(p)).ToList();
    }

    private void ExecuteSubstitution(string team, int playerOff, int playerOn)
    {
        var onCourt = GetOnCourtPlayers(team);
        onCourt.Remove(playerOff);
        onCourt.Add(playerOn);

        var subPairs = teamSubPairs[team];
        if (!subPairs.ContainsKey(playerOff)) subPairs[playerOff] = playerOn;
        if (!subPairs.ContainsKey(playerOn)) subPairs[playerOn] = playerOff;

        if (team == "Home") HomeSubCount++;
        else AwaySubCount++;

        eventHistory.Push(new MatchEvent("Sub", team, playerOff, playerOn));
    }

    private void ShowError(string message)
    {
        ErrorMessage = message;
        IsTeamModalOpen = false;
        IsSubModalOpen = false;
        IsErrorModalOpen = true;
    }

    public async void Undo()
    {
        if (!CanUndo) return;
        var lastEvent = eventHistory.Pop();

        if (lastEvent.Type == "Point")
        {
            if (lastEvent.Team == "Home" && HomeScore > 0) HomeScore--;
            else if (lastEvent.Team == "Away" && AwayScore > 0) AwayScore--;
        }
        else if (lastEvent.Type == "Timeout")
        {
            if (lastEvent.Team == "Home" && HomeTimeOuts > 0) HomeTimeOuts--;
            else if (lastEvent.Team == "Away" && AwayTimeOuts > 0) AwayTimeOuts--;
        }
        else if (lastEvent.Type == "Sub")
        {
            var onCourt = GetOnCourtPlayers(lastEvent.Team);
            onCourt.Remove(lastEvent.PlayerOn);
            onCourt.Add(lastEvent.PlayerOff);

            if (lastEvent.Team == "Home") HomeSubCount--;
            else AwaySubCount--;
        }

        await SaveStateAsync();
    }
}