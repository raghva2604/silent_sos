// Minimal tfjs-node training example.
// Installs: npm install @tensorflow/tfjs-node

const tf = require('@tensorflow/tfjs-node');
const path = require('path');
const fs = require('fs');

async function makeAndTrain() {
  const model = tf.sequential();
  model.add(tf.layers.dense({ inputShape: [10], units: 64, activation: 'relu' }));
  model.add(tf.layers.dense({ units: 32, activation: 'relu' }));
  model.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));

  model.compile({ optimizer: 'adam', loss: 'binaryCrossentropy', metrics: ['accuracy'] });

  // synthetic data
  const x = tf.randomNormal([1024, 10]);
  const y = tf.tidy(() => tf.greater(tf.sum(x, 1), 0).cast('float32'));

  await model.fit(x, y, { epochs: 3, batchSize: 32 });

  const outDir = path.join(process.cwd(), 'models', 'tfjs_model');
  fs.mkdirSync(outDir, { recursive: true });
  await model.save('file://' + outDir);
  console.log('Saved tfjs model to', outDir);
}

makeAndTrain().catch(e => {
  console.error(e);
  process.exit(1);
});
