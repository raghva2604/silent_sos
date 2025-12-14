const tf = require('@tensorflow/tfjs-node');
const path = require('path');

async function run() {
  const modelPath = path.join(process.cwd(), 'models', 'tfjs_model', 'model.json');
  try {
    const model = await tf.loadLayersModel('file://' + modelPath);
    const x = tf.randomNormal([1, 10]);
    const out = model.predict(x);
    out.print();
  } catch (e) {
    console.error('Failed to load model. Run src/tfjs/train.js first.');
    console.error(e);
    process.exit(1);
  }
}

run();
