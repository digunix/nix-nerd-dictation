use std::path::{Path, PathBuf};
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
    /// Returns a human-readable status string
    pub fn status_text(&self) -> &'static str {
        match self {
            DictationState::Stopped => "Stopped",
            DictationState::Active => "Active",
            DictationState::Suspended => "Suspended",
        }
    }
}

/// Information about an available model
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelInfo {
    pub key: String,
    pub size: String,
    pub description: String,
}

const COOKIE_PATH: &str = "/tmp/nerd-dictation.cookie";
const CONFIG_DIR: &str = ".config/nerd-dictation";
const ACTIVE_MODEL_FILE: &str = "active-model";
const DEFAULT_MODEL: &str = "small-en-us";

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

/// Find the models directory path
fn find_models_path() -> Option<PathBuf> {
    // Check environment variable first
    if let Ok(path) = std::env::var("VOSK_MODELS_PATH") {
        let p = PathBuf::from(&path);
        if p.is_dir() {
            return Some(p);
        }
    }

    // Check common paths
    let paths = [
        PathBuf::from("/run/current-system/sw/share/vosk-models"),
        dirs::home_dir()
            .map(|h| h.join(".nix-profile/share/vosk-models"))
            .unwrap_or_default(),
        PathBuf::from("/nix/var/nix/profiles/default/share/vosk-models"),
    ];

    for path in paths {
        if path.is_dir() {
            return Some(path);
        }
    }

    None
}

/// Get the config directory path
fn get_config_dir() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(CONFIG_DIR))
}

/// Get the active model file path
fn get_active_model_path() -> Option<PathBuf> {
    get_config_dir().map(|d| d.join(ACTIVE_MODEL_FILE))
}

/// Discover available models
pub async fn discover_models() -> Vec<ModelInfo> {
    let models_path = match find_models_path() {
        Some(p) => p,
        None => return Vec::new(),
    };

    let mut models = Vec::new();

    // Read directory for .json files
    let mut entries = match fs::read_dir(&models_path).await {
        Ok(e) => e,
        Err(_) => return Vec::new(),
    };

    while let Ok(Some(entry)) = entries.next_entry().await {
        let path = entry.path();
        if path.extension().map_or(false, |e| e == "json") {
            if let Ok(content) = fs::read_to_string(&path).await {
                // Simple JSON parsing without serde
                if let Some(model) = parse_model_json(&content) {
                    models.push(model);
                }
            }
        }
    }

    // Sort by key
    models.sort_by(|a, b| a.key.cmp(&b.key));
    models
}

/// Simple JSON parser for model metadata
fn parse_model_json(content: &str) -> Option<ModelInfo> {
    let key = extract_json_string(content, "key")?;
    let size = extract_json_string(content, "size").unwrap_or_else(|| "Unknown".to_string());
    let description =
        extract_json_string(content, "description").unwrap_or_else(|| "No description".to_string());

    Some(ModelInfo {
        key,
        size,
        description,
    })
}

/// Extract a string value from JSON (simple implementation)
fn extract_json_string(json: &str, key: &str) -> Option<String> {
    let pattern = format!("\"{}\"", key);
    let key_pos = json.find(&pattern)?;
    let after_key = &json[key_pos + pattern.len()..];

    // Find the colon and opening quote
    let colon_pos = after_key.find(':')?;
    let after_colon = &after_key[colon_pos + 1..];
    let quote_start = after_colon.find('"')?;
    let value_start = &after_colon[quote_start + 1..];

    // Find the closing quote
    let quote_end = value_start.find('"')?;
    Some(value_start[..quote_end].to_string())
}

/// Get the currently active model
pub async fn get_active_model() -> String {
    if let Some(path) = get_active_model_path() {
        if let Ok(content) = fs::read_to_string(&path).await {
            let model = content.trim().to_string();
            if !model.is_empty() {
                return model;
            }
        }
    }
    DEFAULT_MODEL.to_string()
}

/// Set the active model
pub async fn set_active_model(model: &str) -> Result<(), std::io::Error> {
    if let Some(config_dir) = get_config_dir() {
        fs::create_dir_all(&config_dir).await?;
        let path = config_dir.join(ACTIVE_MODEL_FILE);
        fs::write(&path, model).await?;
    }
    Ok(())
}
