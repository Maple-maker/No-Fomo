// Vercel serverless entrypoint — re-exports the Express app as the request handler.
// vercel.json routes all paths here; src/index.ts skips app.listen() when process.env.VERCEL is set.
import app from '../src/index'

export default app
