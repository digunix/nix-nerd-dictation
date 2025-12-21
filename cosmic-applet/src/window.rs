use cosmic::app::{self, Core};
use cosmic::iced::time::{self, Duration, Instant};
use cosmic::iced::window;
use cosmic::iced::Subscription;
use cosmic::iced_runtime::core::layout::Limits;
use cosmic::widget::{self, button, container, divider, icon, text, Column};
use cosmic::{Application, Element};
use std::process::Command;

use crate::state::{detect_state, discover_models, get_active_model, set_active_model, DictationState, ModelInfo};

const APP_ID: &str = "com.digunix.CosmicAppletNerdDictation";
const POLL_INTERVAL_MS: u64 = 1000;

// Embed SVG icons directly in the binary
const ICON_RED: &[u8] = include_bytes!("../resources/icons/microphone-red-symbolic.svg");
const ICON_GREEN: &[u8] = include_bytes!("../resources/icons/microphone-green-symbolic.svg");
const ICON_YELLOW: &[u8] = include_bytes!("../resources/icons/microphone-yellow-symbolic.svg");

pub struct Window {
    core: Core,
    popup: Option<window::Id>,
    state: DictationState,
    models: Vec<ModelInfo>,
    active_model: String,
}

#[derive(Debug, Clone)]
pub enum Message {
    TogglePopup,
    PopupClosed(window::Id),
    StateUpdated(DictationState),
    ModelsDiscovered(Vec<ModelInfo>),
    ActiveModelLoaded(String),
    SelectModel(String),
    ModelSet(Result<(), String>),
    Tick(Instant),
    Start,
    Stop,
    Suspend,
    Resume,
}

impl Window {
    fn get_icon_bytes(&self) -> &'static [u8] {
        match self.state {
            DictationState::Stopped => ICON_RED,
            DictationState::Active => ICON_GREEN,
            DictationState::Suspended => ICON_YELLOW,
        }
    }
}

impl Application for Window {
    type Executor = cosmic::SingleThreadExecutor;
    type Flags = ();
    type Message = Message;

    const APP_ID: &'static str = APP_ID;

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn style(&self) -> Option<cosmic::iced_runtime::Appearance> {
        Some(cosmic::applet::style())
    }

    fn init(core: Core, _flags: ()) -> (Self, app::Task<Message>) {
        let app = Window {
            core,
            popup: None,
            state: DictationState::default(),
            models: Vec::new(),
            active_model: String::from("small-en-us"),
        };

        // Initialize state and models
        let state_task = cosmic::Task::perform(detect_state(), |s| {
            cosmic::Action::App(Message::StateUpdated(s))
        });

        let models_task = cosmic::Task::perform(discover_models(), |models| {
            cosmic::Action::App(Message::ModelsDiscovered(models))
        });

        let active_task = cosmic::Task::perform(get_active_model(), |model| {
            cosmic::Action::App(Message::ActiveModelLoaded(model))
        });

        (app, cosmic::Task::batch([state_task, models_task, active_task]))
    }

    fn update(&mut self, message: Message) -> app::Task<Message> {
        match message {
            Message::TogglePopup => {
                if let Some(popup_id) = self.popup.take() {
                    return cosmic::iced::platform_specific::shell::commands::popup::destroy_popup(
                        popup_id,
                    );
                } else {
                    let new_id = window::Id::unique();
                    self.popup = Some(new_id);

                    let mut popup_settings = self.core.applet.get_popup_settings(
                        self.core.main_window_id().unwrap(),
                        new_id,
                        Some((250, 200)),
                        None,
                        None,
                    );

                    popup_settings.positioner.size_limits = Limits::NONE
                        .min_width(200.0)
                        .min_height(120.0)
                        .max_height(350.0)
                        .max_width(300.0);

                    // Refresh models when popup opens
                    let models_task = cosmic::Task::perform(discover_models(), |models| {
                        cosmic::Action::App(Message::ModelsDiscovered(models))
                    });

                    let popup_task = cosmic::iced::platform_specific::shell::commands::popup::get_popup(
                        popup_settings,
                    );

                    return cosmic::Task::batch([popup_task, models_task]);
                }
            }

            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }

            Message::StateUpdated(new_state) => {
                self.state = new_state;
            }

            Message::ModelsDiscovered(models) => {
                self.models = models;
            }

            Message::ActiveModelLoaded(model) => {
                self.active_model = model;
            }

            Message::SelectModel(model) => {
                let model_clone = model.clone();
                self.active_model = model;
                return cosmic::Task::perform(
                    async move {
                        set_active_model(&model_clone)
                            .await
                            .map_err(|e| e.to_string())
                    },
                    |result| cosmic::Action::App(Message::ModelSet(result)),
                );
            }

            Message::ModelSet(_result) => {
                // Could show notification on error, but for now just ignore
            }

            Message::Tick(_) => {
                return cosmic::Task::perform(detect_state(), |s| {
                    cosmic::Action::App(Message::StateUpdated(s))
                });
            }

            Message::Start => {
                let _ = Command::new("nerd-dictation").arg("begin").spawn();
                return cosmic::Task::perform(
                    async {
                        tokio::time::sleep(Duration::from_millis(500)).await;
                        detect_state().await
                    },
                    |s| cosmic::Action::App(Message::StateUpdated(s)),
                );
            }

            Message::Stop => {
                let _ = Command::new("nerd-dictation").arg("end").spawn();
                return cosmic::Task::perform(
                    async {
                        tokio::time::sleep(Duration::from_millis(200)).await;
                        detect_state().await
                    },
                    |s| cosmic::Action::App(Message::StateUpdated(s)),
                );
            }

            Message::Suspend => {
                let _ = Command::new("nerd-dictation").arg("suspend").spawn();
                return cosmic::Task::perform(
                    async {
                        tokio::time::sleep(Duration::from_millis(200)).await;
                        detect_state().await
                    },
                    |s| cosmic::Action::App(Message::StateUpdated(s)),
                );
            }

            Message::Resume => {
                let _ = Command::new("nerd-dictation").arg("resume").spawn();
                return cosmic::Task::perform(
                    async {
                        tokio::time::sleep(Duration::from_millis(200)).await;
                        detect_state().await
                    },
                    |s| cosmic::Action::App(Message::StateUpdated(s)),
                );
            }
        }
        cosmic::Task::none()
    }

    fn view(&self) -> Element<Message> {
        let icon_handle = icon::from_svg_bytes(self.get_icon_bytes());
        let suggested_size = self.core.applet.suggested_size(false);
        let icon_widget = icon::icon(icon_handle)
            .size(suggested_size.0.min(suggested_size.1));

        let padding = self.core.applet.suggested_padding(false);
        widget::button::custom(icon_widget)
            .padding([padding.0, padding.1])
            .class(cosmic::theme::Button::AppletIcon)
            .on_press_down(Message::TogglePopup)
            .into()
    }

    fn view_window(&self, id: window::Id) -> Element<Message> {
        if self.popup != Some(id) {
            return container(text::body("")).into();
        }

        let status_text = text::body(format!("Status: {}", self.state.status_text()));

        let mut content: Vec<Element<Message>> = vec![
            status_text.into(),
            widget::vertical_space().height(8).into(),
        ];

        // Model selector section
        if !self.models.is_empty() {
            content.push(text::caption("Model:").into());
            content.push(widget::vertical_space().height(4).into());

            for model in &self.models {
                let is_active = model.key == self.active_model;
                let label = format!(
                    "{} {} ({})",
                    if is_active { "●" } else { "○" },
                    model.key,
                    model.size
                );

                let model_key = model.key.clone();
                let btn = if is_active {
                    button::text(label)
                        .width(cosmic::iced::Length::Fill)
                } else {
                    button::text(label)
                        .on_press(Message::SelectModel(model_key))
                        .width(cosmic::iced::Length::Fill)
                };
                content.push(btn.into());
                content.push(widget::vertical_space().height(2).into());
            }

            content.push(widget::vertical_space().height(4).into());
        }

        content.push(divider::horizontal::default().into());
        content.push(widget::vertical_space().height(8).into());

        // Control buttons based on state
        match self.state {
            DictationState::Stopped => {
                content.push(
                    button::standard("Start Dictation")
                        .on_press(Message::Start)
                        .width(cosmic::iced::Length::Fill)
                        .into(),
                );
            }
            DictationState::Active => {
                content.push(
                    button::standard("Suspend")
                        .on_press(Message::Suspend)
                        .width(cosmic::iced::Length::Fill)
                        .into(),
                );
                content.push(widget::vertical_space().height(8).into());
                content.push(
                    button::destructive("Stop")
                        .on_press(Message::Stop)
                        .width(cosmic::iced::Length::Fill)
                        .into(),
                );
            }
            DictationState::Suspended => {
                content.push(
                    button::standard("Resume")
                        .on_press(Message::Resume)
                        .width(cosmic::iced::Length::Fill)
                        .into(),
                );
                content.push(widget::vertical_space().height(8).into());
                content.push(
                    button::destructive("Stop")
                        .on_press(Message::Stop)
                        .width(cosmic::iced::Length::Fill)
                        .into(),
                );
            }
        }

        let column = Column::with_children(content).padding(16);

        self.core
            .applet
            .popup_container(column)
            .max_height(350.)
            .max_width(300.)
            .into()
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(Duration::from_millis(POLL_INTERVAL_MS)).map(Message::Tick)
    }

    fn on_close_requested(&self, id: window::Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }
}
