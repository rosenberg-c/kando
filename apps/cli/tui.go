package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"kando/apps/cli/ui"
	"kando/apps/cli/internal/cli"
)

func runTUI(ctx context.Context, service *cli.Service, store cli.TokenStore, input io.Reader, output io.Writer) error {
	m := newTUIModel(ctx, service, store)
	p := tea.NewProgram(m, tea.WithInput(input), tea.WithOutput(output), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		return err
	}

	return nil
}

type tuiAction int

const (
	actionLogin tuiAction = iota
	actionStatus
	actionMe
	actionLogout
)

type tuiInputMode int

const (
	inputNone tuiInputMode = iota
	inputEmail
	inputPassword
)

type actionResultMsg struct {
	text     string
	err      error
	signedIn *bool
}

type tuiModel struct {
	service    *cli.Service
	store      cli.TokenStore
	runWithCtx func(func(context.Context) tea.Msg) tea.Cmd
	cursor     int
	logs       []string
	busy       bool
	help       bool
	inputMode  tuiInputMode
	email      string
	signedIn   bool
	input      textinput.Model
	width      int
	height     int

	headerStyle   lipgloss.Style
	paneStyle     lipgloss.Style
	selectedStyle lipgloss.Style
	mutedStyle    lipgloss.Style
	errorStyle    lipgloss.Style
}

func newTUIModel(ctx context.Context, service *cli.Service, store cli.TokenStore) tuiModel {
	in := textinput.New()
	in.Prompt = ""
	signedIn := hasStoredSession(store)
	logs := []string{ui.T("cli.tui.log.welcome")}
	busy := false
	if signedIn {
		busy = true
		logs = append(logs, ui.T("cli.tui.loading_validate"))
	}

	return tuiModel{
		service: service,
		store:   store,
		runWithCtx: func(run func(context.Context) tea.Msg) tea.Cmd {
			return func() tea.Msg {
				return run(ctx)
			}
		},
		logs:     logs,
		busy:     busy,
		signedIn: signedIn,
		input:    in,
		headerStyle: lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("212")),
		paneStyle: lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240")).
			Padding(0, 1),
		selectedStyle: lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("230")).
			Background(lipgloss.Color("62")),
		mutedStyle: lipgloss.NewStyle().Foreground(lipgloss.Color("245")),
		errorStyle: lipgloss.NewStyle().Foreground(lipgloss.Color("204")),
	}
}

func (m tuiModel) Init() tea.Cmd {
	if !m.signedIn {
		return nil
	}

	return m.validateSessionCmd()
}

func (m tuiModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch typed := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = typed.Width
		m.height = typed.Height
		return m, nil
	case actionResultMsg:
		m.busy = false
		if typed.signedIn != nil {
			m.signedIn = *typed.signedIn
			m.clampCursor()
		}
		if typed.err != nil {
			m.pushError(typed.err)
			return m, nil
		}
		if typed.text != "" {
			m.pushInfo(typed.text)
		}
		return m, nil
	case tea.KeyMsg:
		if m.inputMode != inputNone {
			return m.updateInput(typed)
		}

		switch typed.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "?":
			m.help = !m.help
			return m, nil
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
			return m, nil
		case "down", "j":
			actions := m.availableActions()
			if m.cursor < len(actions)-1 {
				m.cursor++
			}
			return m, nil
		case "enter":
			if !m.signedIn {
				return m.handleAction(actionLogin)
			}
			if m.busy {
				return m, nil
			}
			actions := m.availableActions()
			if len(actions) == 0 {
				return m, nil
			}
			m.clampCursor()
			return m.handleAction(actions[m.cursor])
		case "l":
			if !m.signedIn {
				return m.handleAction(actionLogin)
			}
			return m, nil
		}
	}

	return m, nil
}

func (m tuiModel) updateInput(key tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch key.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "esc":
		m.inputMode = inputNone
		m.input.Blur()
		m.pushInfo(ui.T("cli.tui.login.cancelled"))
		return m, nil
	case "enter":
		value := strings.TrimSpace(m.input.Value())
		if m.inputMode == inputEmail {
			if value == "" {
				m.pushError(fmt.Errorf(ui.T("cli.validation.email_required")))
				return m, nil
			}
			m.email = value
			m.inputMode = inputPassword
			m.input.SetValue("")
			m.input.Placeholder = ui.T("cli.tui.password_placeholder")
			m.input.EchoMode = textinput.EchoPassword
			m.input.EchoCharacter = '*'
			return m, nil
		}

		if value == "" {
			m.pushError(fmt.Errorf(ui.T("cli.validation.password_required")))
			return m, nil
		}

		email := m.email
		password := value
		m.inputMode = inputNone
		m.input.Blur()
		m.busy = true
		m.pushInfo(ui.T("cli.tui.loading_login"))
		return m, m.loginCmd(email, password)
	}

	var cmd tea.Cmd
	m.input, cmd = m.input.Update(key)
	return m, cmd
}

func (m tuiModel) handleAction(action tuiAction) (tea.Model, tea.Cmd) {
	switch action {
	case actionLogin:
		m.inputMode = inputEmail
		m.input.SetValue("")
		m.input.Placeholder = ui.T("cli.tui.email_placeholder")
		m.input.EchoMode = textinput.EchoNormal
		m.input.Focus()
		return m, nil
	case actionStatus:
		m.busy = true
		return m, m.statusCmd()
	case actionMe:
		m.busy = true
		m.pushInfo(ui.T("cli.tui.loading_me"))
		return m, m.meCmd()
	case actionLogout:
		m.busy = true
		m.pushInfo(ui.T("cli.tui.loading_logout"))
		return m, m.logoutCmd()
	default:
		return m, nil
	}
}

func (m tuiModel) View() string {
	header := m.headerStyle.Render(ui.T("cli.tui.title")) + "\n" + m.mutedStyle.Render(ui.T("cli.tui.subtitle"))
	if m.help {
		return lipgloss.JoinVertical(lipgloss.Left, header, "", m.renderHelp(), "", m.renderFooter())
	}
	if m.inputMode != inputNone {
		return lipgloss.JoinVertical(lipgloss.Left, header, "", m.renderInputPanel(), "", m.renderFooter())
	}
	if !m.signedIn {
		return lipgloss.JoinVertical(lipgloss.Left, header, "", m.renderSignedOutPage(), "", m.renderFooter())
	}

	sideWidth := m.sidePaneWidth()
	shortcutWidth := m.shortcutPaneWidth()
	logWidth := m.logPaneWidth()

	spacerWidth := m.width - sideWidth - logWidth - shortcutWidth - 4
	if spacerWidth < 1 {
		spacerWidth = 1
	}

	body := lipgloss.JoinHorizontal(
		lipgloss.Top,
		m.renderSidePane(sideWidth),
		" ",
		m.renderLogPane(logWidth),
		lipgloss.NewStyle().Width(spacerWidth).Render(""),
		m.renderShortcutPane(shortcutWidth),
	)
	return lipgloss.JoinVertical(lipgloss.Left, header, "", body, "", m.renderFooter())
}

func (m tuiModel) renderSignedOutPage() string {
	shortcutWidth := m.shortcutPaneWidth()
	pageWidth := m.width - shortcutWidth - 3
	if pageWidth < 48 {
		pageWidth = 48
	}

	lines := []string{
		ui.T("cli.tui.signed_out_title"),
		"",
		ui.T("cli.tui.signed_out_body"),
		"",
		ui.T("cli.tui.signed_out_hint"),
	}

	spacerWidth := m.width - pageWidth - shortcutWidth - 2
	if spacerWidth < 1 {
		spacerWidth = 1
	}

	return lipgloss.JoinHorizontal(
		lipgloss.Top,
		m.paneStyle.Width(pageWidth).Render(strings.Join(lines, "\n")),
		lipgloss.NewStyle().Width(spacerWidth).Render(""),
		m.renderShortcutPane(shortcutWidth),
	)
}

func (m tuiModel) renderSidePane(width int) string {
	actions := m.availableActions()
	actionLines := []string{ui.T("cli.tui.actions_title"), ""}
	for i, action := range actions {
		label := m.actionLabel(action)
		if i == m.cursor {
			actionLines = append(actionLines, m.selectedStyle.Render("> "+label))
			continue
		}
		actionLines = append(actionLines, "  "+label)
	}

	if m.busy {
		actionLines = append(actionLines, "", m.mutedStyle.Render(ui.T("cli.tui.busy")))
	}

	return m.paneStyle.Width(width).Render(strings.Join(actionLines, "\n"))
}

func (m tuiModel) renderLogPane(width int) string {
	maxLines := maxInt(8, m.height-10)
	start := 0
	if len(m.logs) > maxLines {
		start = len(m.logs) - maxLines
	}
	lines := append([]string{ui.T("cli.tui.log_title"), ""}, m.logs[start:]...)
	return m.paneStyle.Width(width).Render(strings.Join(lines, "\n"))
}

func (m tuiModel) renderShortcutPane(width int) string {
	lines := []string{ui.T("cli.tui.shortcuts_title"), ""}
	if !m.signedIn {
		lines = append(lines,
			ui.T("cli.tui.shortcut.sign_in"),
			ui.T("cli.tui.shortcut.help"),
			ui.T("cli.tui.shortcut.quit"),
		)
	} else {
		lines = append(lines,
			ui.T("cli.tui.shortcut.move"),
			ui.T("cli.tui.shortcut.run"),
			ui.T("cli.tui.shortcut.help"),
			ui.T("cli.tui.shortcut.quit"),
		)
	}

	return m.paneStyle.Width(width).Render(strings.Join(lines, "\n"))
}

func (m tuiModel) sidePaneWidth() int {
	return maxInt(30, m.width/4)
}

func (m tuiModel) shortcutPaneWidth() int {
	return 24
}

func (m tuiModel) logPaneWidth() int {
	logWidth := m.width - 62
	logWidth = maxInt(34, logWidth)
	logWidth = minInt(52, logWidth)
	return logWidth
}

func (m tuiModel) renderInputPanel() string {
	label := ui.T("cli.tui.email_prompt")
	if m.inputMode == inputPassword {
		label = ui.T("cli.password.prompt")
	}

	lines := []string{
		ui.T("cli.tui.login_title"),
		"",
		label,
		m.input.View(),
		"",
		m.mutedStyle.Render(ui.T("cli.tui.login_hint")),
	}

	return m.paneStyle.Width(maxInt(50, m.width-4)).Render(strings.Join(lines, "\n"))
}

func (m tuiModel) renderHelp() string {
	lines := []string{
		ui.T("cli.tui.help_title"),
		"",
		ui.T("cli.tui.help_nav"),
		ui.T("cli.tui.help_run"),
		ui.T("cli.tui.help_help"),
		ui.T("cli.tui.help_quit"),
	}

	return m.paneStyle.Width(maxInt(50, m.width-4)).Render(strings.Join(lines, "\n"))
}

func (m tuiModel) renderFooter() string {
	return m.mutedStyle.Render(ui.T("cli.tui.footer"))
}

func (m tuiModel) actionLabel(action tuiAction) string {
	switch action {
	case actionStatus:
		return ui.T("cli.tui.action.status")
	case actionMe:
		return ui.T("cli.tui.action.me")
	case actionLogout:
		return ui.T("cli.tui.action.logout")
	default:
		return ""
	}
}

func (m tuiModel) availableActions() []tuiAction {
	if !m.signedIn {
		return []tuiAction{actionLogin}
	}

	return []tuiAction{actionStatus, actionMe, actionLogout}
}

func (m *tuiModel) clampCursor() {
	actions := m.availableActions()
	if len(actions) == 0 {
		m.cursor = 0
		return
	}
	if m.cursor < 0 {
		m.cursor = 0
		return
	}
	if m.cursor >= len(actions) {
		m.cursor = len(actions) - 1
	}
}

func (m *tuiModel) pushInfo(text string) {
	if strings.TrimSpace(text) == "" {
		return
	}
	m.appendLog(time.Now().Format("15:04:05") + " " + text)
}

func (m *tuiModel) pushError(err error) {
	if err == nil {
		return
	}
	m.appendLog(m.errorStyle.Render(time.Now().Format("15:04:05") + " " + err.Error()))
}

func (m *tuiModel) appendLog(line string) {
	m.logs = append(m.logs, line)
	if len(m.logs) > 200 {
		m.logs = m.logs[len(m.logs)-200:]
	}
}

func (m tuiModel) loginCmd(email, password string) tea.Cmd {
	return m.runWithCtx(func(ctx context.Context) tea.Msg {
		if err := m.service.Login(ctx, email, password); err != nil {
			return actionResultMsg{err: fmt.Errorf(ui.T("cli.login.failed"), err)}
		}
		signedIn := true
		return actionResultMsg{text: ui.T("cli.login.success"), signedIn: &signedIn}
	})
}

func (m tuiModel) statusCmd() tea.Cmd {
	return m.runWithCtx(func(context.Context) tea.Msg {
		state, err := m.store.Load()
		if err != nil {
			if errors.Is(err, cli.ErrTokenStateNotFound) {
				signedIn := false
				return actionResultMsg{text: ui.T("cli.tui.status_logged_out"), signedIn: &signedIn}
			}
			return actionResultMsg{err: fmt.Errorf(ui.T("cli.tui.status_failed"), err)}
		}

		signedIn := true
		return actionResultMsg{text: fmt.Sprintf(ui.T("cli.tui.status_summary"), state.AccessTokenExpiresAt.Format("2006-01-02 15:04:05Z07:00")), signedIn: &signedIn}
	})
}

func (m tuiModel) meCmd() tea.Cmd {
	return m.runWithCtx(func(ctx context.Context) tea.Msg {
		body, err := m.service.Me(ctx)
		if err != nil {
			return actionResultMsg{err: fmt.Errorf(ui.T("cli.me.failed"), err)}
		}
		return actionResultMsg{text: fmt.Sprintf("%s\n%s", ui.T("cli.tui.me_label"), string(body))}
	})
}

func (m tuiModel) logoutCmd() tea.Cmd {
	return m.runWithCtx(func(ctx context.Context) tea.Msg {
		if err := m.service.Logout(ctx); err != nil {
			return actionResultMsg{err: fmt.Errorf(ui.T("cli.logout.failed"), err)}
		}
		signedIn := false
		return actionResultMsg{text: ui.T("cli.logout.success"), signedIn: &signedIn}
	})
}

func (m tuiModel) validateSessionCmd() tea.Cmd {
	return m.runWithCtx(func(ctx context.Context) tea.Msg {
		valid, err := m.service.ValidateSession(ctx)
		if err != nil {
			return actionResultMsg{err: fmt.Errorf(ui.T("cli.tui.validate_failed"), err)}
		}
		if !valid {
			signedIn := false
			return actionResultMsg{text: ui.T("cli.tui.status_logged_out"), signedIn: &signedIn}
		}

		signedIn := true
		return actionResultMsg{text: ui.T("cli.tui.validate_success"), signedIn: &signedIn}
	})
}

func hasStoredSession(store cli.TokenStore) bool {
	state, err := store.Load()
	if err != nil {
		return false
	}

	return strings.TrimSpace(state.RefreshToken) != ""
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
