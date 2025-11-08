function clean(obj) {
  if (!obj || typeof obj !== "object") return;

  for (const key of Object.keys(obj)) {
    if (key.startsWith("$") || key.includes(".")) {
      delete obj[key]; // dangerous key removed
    } else if (typeof obj[key] === "object") {
      clean(obj[key]); // recurse
    }
  }
}

export const mongoSanitizeSafe = (req, res, next) => {
  if (req.body) clean(req.body); 
  if (req.params) clean(req.params); 
  next();
};
