import sys
import os

try:
    import tensorflow as tf  # type: ignore[import]
    from tensorflow.keras.preprocessing.image import ImageDataGenerator  # type: ignore[import]
    from tensorflow.keras import layers, models  # type: ignore[import]
except ImportError as e:
    print(f'❌ Missing dependencies: {e}')
    print('   Install with: pip install tensorflow')
    sys.exit(1)

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
DATASET_DIR = "image_danger_dataset"
EPOCHS = 25

# 1. Data Augmentation
train_gen = ImageDataGenerator(
    rescale=1/255.,
    validation_split=0.2,
    rotation_range=20,
    zoom_range=0.2,
    shear_range=0.2,
    horizontal_flip=True
)

train_data = train_gen.flow_from_directory(
    DATASET_DIR,
    target_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    subset="training"
)

val_data = train_gen.flow_from_directory(
    DATASET_DIR,
    target_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    subset="validation"
)

num_classes = len(train_data.class_indices)
print("Classes:", train_data.class_indices)

# 2. Base model (MobileNetV2)
base = tf.keras.applications.MobileNetV2(
    weights="imagenet",
    include_top=False,
    input_shape=(*IMAGE_SIZE, 3)
)
base.trainable = False  # freeze backbone for fast training

model = models.Sequential([
    base,
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.3),
    layers.Dense(128, activation="relu"),
    layers.Dense(num_classes, activation="softmax")
])

model.compile(
    optimizer=tf.keras.optimizers.Adam(1e-4),
    loss="categorical_crossentropy",
    metrics=["accuracy"]
)

# 3. Train model
history = model.fit(
    train_data,
    validation_data=val_data,
    epochs=EPOCHS
)

# 4. Save Keras model
os.makedirs("training/output", exist_ok=True)
model.save("training/output/danger_image_model.h5")
print("Saved training/output/danger_image_model.h5")

# 5. Convert to TFLite (quantized)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open("training/output/danger_image_model.tflite", "wb") as f:
    f.write(tflite_model)

print("Saved training/output/danger_image_model.tflite")
