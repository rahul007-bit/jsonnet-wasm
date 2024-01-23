use std::{fs, path::Path};

use jrsonnet_evaluator::EvaluationState;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn jsonnet(path: &str) -> String {
    let vm = EvaluationState::default();
    vm.with_stdlib();
    let code = fs::read_to_string(path).unwrap();
    let value = vm
        .run_in_state(|| vm.evaluate_snippet_raw(Path::new(path).into(), code.into()))
        .unwrap();
    serde_json::Value::try_from(&value).unwrap().to_string()
}
