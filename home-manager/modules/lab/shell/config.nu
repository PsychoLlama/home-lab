$env.config = {
  edit_mode: vi
  show_banner: false
  footer_mode: 20
  history: {
    file_format: sqlite
    isolation: true
  }
  table: {
    mode: rounded
    header_on_separator: true
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

  # Pulled from `config nu --default`
  shell_integration: {
    osc2: true
    osc7: true
    osc8: true
    osc9_9: false
    osc133: true
    reset_application_mode: true
  }
}
