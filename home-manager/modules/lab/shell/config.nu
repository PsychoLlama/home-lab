$env.config = {
  edit_mode: vi
  shell_integration: true
  show_banner: false
  footer_mode: 20
  history: {
    file_format: sqlite
    isolation: true
  }
  table: {
    mode: psql
  }
  cursor_shape: {
    vi_normal: block
    vi_insert: line
  }
  completions: {
    case_sensitive: false
    partial: false
    quick: true
    external: {
      enable: true
    }
  }
}
