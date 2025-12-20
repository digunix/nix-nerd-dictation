mod state;
mod window;

use crate::window::Window;

fn main() -> cosmic::iced::Result {
    tracing_subscriber::fmt::init();
    cosmic::applet::run::<Window>(())
}
