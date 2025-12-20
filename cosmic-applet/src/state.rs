use std::path::Path;
use tokio::fs;

/// Represents the current state of nerd-dictation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum DictationState {
    #[default]
    Stopped,
    Active,
    Suspended,
}

impl DictationState {
    /// Returns the icon name for this state
    pub fn icon_name(&self) -> &'static str {
        match self {
            DictationState::Stopped => "microphone-red-symbolic",
            DictationState::Active => "microphone-green-symbolic",
            DictationState::Suspended => "microphone-yellow-symbolic",
        }
    }

    /// Returns a human-readable status string
    pub fn status_text(&self) -> &'static str {
        match self {
            DictationState::Stopped => "Stopped",
            DictationState::Active => "Active",
            DictationState::Suspended => "Suspended",
        }
    }
}

const COOKIE_PATH: &str = "/tmp/nerd-dictation.cookie";

/// Detect the current state of nerd-dictation by:
/// 1. Checking if cookie file exists at /tmp/nerd-dictation.cookie
/// 2. Reading PID from cookie file
/// 3. Checking /proc/$PID/status for process state
pub async fn detect_state() -> DictationState {
    let cookie_path = Path::new(COOKIE_PATH);
    if !cookie_path.exists() {
        return DictationState::Stopped;
    }

    let pid = match fs::read_to_string(cookie_path).await {
        Ok(content) => match content.trim().parse::<u32>() {
            Ok(pid) => pid,
            Err(_) => return DictationState::Stopped,
        },
        Err(_) => return DictationState::Stopped,
    };

    let status_path = format!("/proc/{}/status", pid);
    let status_content = match fs::read_to_string(&status_path).await {
        Ok(content) => content,
        Err(_) => return DictationState::Stopped,
    };

    for line in status_content.lines() {
        if line.starts_with("State:") {
            let state_char = line
                .split_whitespace()
                .nth(1)
                .and_then(|s| s.chars().next());

            return match state_char {
                Some('T') | Some('t') => DictationState::Suspended,
                Some('R') | Some('S') | Some('D') => DictationState::Active,
                _ => DictationState::Stopped,
            };
        }
    }

    DictationState::Stopped
}
