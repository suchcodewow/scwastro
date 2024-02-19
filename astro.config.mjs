import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      title: "SuchCodeWow",
      logo: {
        src: "./src/assets/wow.png",
      },
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
      social: {
        github: "https://github.com/suchcodewow/scwastro",
      },
      sidebar: [
        {
          label: "Guides",
          items: [
            // Each item here is one entry in the navigation menu.
            { label: "Example Guide", link: "/guides/example/" },
          ],
        },
        {
          label: "Reference",
          autogenerate: { directory: "reference" },
        },
      ],
    }),
  ],
});
