use cosmic::app::{self, Core};
use cosmic::iced::time::{self, Duration, Instant};
use cosmic::iced::window;
use cosmic::iced::Subscription;
use cosmic::iced_runtime::core::layout::Limits;
use cosmic::widget::{self, button, container, divider, icon, text, Column};
use cosmic::{Application, Element};
use std::process::Command;

use crate::state::{detect_state, DictationState};

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
}

#[derive(Debug, Clone)]
pub enum Message {
    TogglePopup,
    PopupClosed(window::Id),
    StateUpdated(DictationState),
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
        };

        let task = cosmic::Task::perform(detect_state(), |s| {
            cosmic::Action::App(Message::StateUpdated(s))
        });

        (app, task)
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
                        Some((200, 150)),
                        None,
                        None,
                    );

                    popup_settings.positioner.size_limits = Limits::NONE
                        .min_width(180.0)
                        .min_height(100.0)
                        .max_height(200.0)
                        .max_width(250.0);

                    return cosmic::iced::platform_specific::shell::commands::popup::get_popup(
                        popup_settings,
                    );
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
            divider::horizontal::default().into(),
            widget::vertical_space().height(8).into(),
        ];

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
            .max_height(200.)
            .max_width(250.)
            .into()
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(Duration::from_millis(POLL_INTERVAL_MS)).map(Message::Tick)
    }

    fn on_close_requested(&self, id: window::Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }
}
