use axum::{
    extract::{Path, Query},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs,
    path::{PathBuf, Path as StdPath},
};
use tower_http::cors::CorsLayer;

#[derive(Serialize, Deserialize)]
struct FileInfo {
    name: String,
    path: String,
    is_directory: bool,
    size: Option<u64>,
    modified: Option<String>,
    mime_type: Option<String>,
}

#[derive(Deserialize)]
struct BrowseQuery {
    path: Option<String>,
}

async fn browse_files(Query(params): Query<BrowseQuery>) -> Result<Json<Vec<FileInfo>>, StatusCode> {
    let base_path = std::env::var("NAS_ROOT_PATH").unwrap_or_else(|_| ".".to_string());
    let requested_path = params.path.unwrap_or_default();

    let full_path = PathBuf::from(&base_path).join(&requested_path);

    if !full_path.exists() || !full_path.is_dir() {
        return Err(StatusCode::NOT_FOUND);
    }

    let mut files = Vec::new();

    if let Ok(entries) = fs::read_dir(&full_path) {
        for entry in entries.flatten() {
            let path = entry.path();
            let metadata = entry.metadata().ok();

            let file_info = FileInfo {
                name: path.file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                path: path.strip_prefix(&base_path)
                    .unwrap_or(&path)
                    .to_string_lossy()
                    .to_string(),
                is_directory: path.is_dir(),
                size: metadata.as_ref().and_then(|m| if m.is_file() { Some(m.len()) } else { None }),
                modified: metadata.as_ref().and_then(|m| {
                    m.modified().ok().and_then(|time| {
                        chrono::DateTime::<chrono::Utc>::from(time).format("%Y-%m-%d %H:%M:%S").to_string().into()
                    })
                }),
                mime_type: if path.is_file() {
                    mime_guess::from_path(&path).first().map(|m| m.to_string())
                } else {
                    None
                },
            };

            files.push(file_info);
        }
    }

    files.sort_by(|a, b| {
        match (a.is_directory, b.is_directory) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        }
    });

    Ok(Json(files))
}

async fn get_file_info(Path(file_path): Path<String>) -> Result<Json<FileInfo>, StatusCode> {
    let base_path = std::env::var("NAS_ROOT_PATH").unwrap_or_else(|_| ".".to_string());
    let full_path = PathBuf::from(&base_path).join(&file_path);

    if !full_path.exists() {
        return Err(StatusCode::NOT_FOUND);
    }

    let metadata = fs::metadata(&full_path).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let file_info = FileInfo {
        name: full_path.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Unknown")
            .to_string(),
        path: file_path,
        is_directory: full_path.is_dir(),
        size: if metadata.is_file() { Some(metadata.len()) } else { None },
        modified: metadata.modified().ok().and_then(|time| {
            chrono::DateTime::<chrono::Utc>::from(time).format("%Y-%m-%d %H:%M:%S").to_string().into()
        }),
        mime_type: if full_path.is_file() {
            mime_guess::from_path(&full_path).first().map(|m| m.to_string())
        } else {
            None
        },
    };

    Ok(Json(file_info))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/api/browse", get(browse_files))
        .route("/api/file/*path", get(get_file_info))
        .layer(CorsLayer::permissive());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .unwrap();

    println!("NAS Backend server running on http://0.0.0.0:3000");
    println!("Set NAS_ROOT_PATH environment variable to specify root directory");

    axum::serve(listener, app).await.unwrap();
}
