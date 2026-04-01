import { z } from "zod";

export const interpretRequestSchema = z.object({
  situation: z.string().trim().min(3, "Situation must be at least 3 characters.")
});

export const interpretationSchema = z.object({
  title: z.string().min(1),
  confidence: z.number().min(0).max(1),
  rationale: z.string().min(1)
});

export const interpretResponseSchema = z.object({
  interpretations: z.array(interpretationSchema),
  templateUsed: z.string(),
  warnings: z.array(z.string())
});

export type InterpretRequest = z.infer<typeof interpretRequestSchema>;
export type Interpretation = z.infer<typeof interpretationSchema>;
export type InterpretResponse = z.infer<typeof interpretResponseSchema>;

export type CytoscapeElement = {
  data: Record<string, unknown>;
};

export type GraphResponse = {
  elements: CytoscapeElement[];
};
